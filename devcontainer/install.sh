#!/usr/bin/env bash
set -uxo pipefail

echo "=== Dev Container: Docker Installation ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# Verification helpers (inline -- no separate utilities file needed for install)
#==============================================================================

verify_or_fail() {
    local label="$1"
    shift
    if "$@"; then
        echo "PASS: $label"
    else
        echo "FAIL: $label"
        return 1
    fi
}

#==============================================================================
# Step 0: Cleanup stale processes from previous sessions
#==============================================================================

cleanup_stale_processes() {
    echo "Cleaning up stale Docker/containerd processes..."
    sudo pkill -9 dockerd 2>/dev/null || true
    sudo pkill -9 containerd 2>/dev/null || true
    sudo pkill -9 docker-proxy 2>/dev/null || true
    sleep 2
    sudo killall -9 dockerd 2>/dev/null || true
    sudo killall -9 containerd 2>/dev/null || true

    sudo rm -f /var/run/docker.pid /var/run/docker.sock
    sudo rm -rf /var/run/docker/*
    sudo rm -f /run/containerd/containerd.sock /var/run/containerd/containerd.sock
    sudo rm -rf /var/run/containerd /run/containerd
    echo "Cleanup done"
}

#==============================================================================
# Step 1: Install Docker
#==============================================================================

install_docker() {
    if command -v docker &>/dev/null; then
        echo "Docker already installed: $(docker --version 2>&1)"
        return 0
    fi

    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh || { echo "Docker install failed"; return 1; }
    rm -f /tmp/get-docker.sh

    # Add user to docker group
    local user=$(whoami)
    if ! groups "$user" | grep -q docker; then
        sudo usermod -aG docker "$user" || echo "Warning: could not add $user to docker group"
    fi
}

verify_docker_installed() {
    command -v docker &>/dev/null && command -v dockerd &>/dev/null
}

#==============================================================================
# Step 2: Apply daemon config (VFS driver, no iptables, no bridge)
#==============================================================================

apply_daemon_config() {
    local src="${SCRIPT_DIR}/daemon.json"
    local dest="/etc/docker/daemon.json"

    if [ ! -f "$src" ]; then
        echo "daemon.json not found at $src"
        return 1
    fi

    sudo mkdir -p /etc/docker
    sudo cp "$src" "$dest"
    echo "Daemon config applied to $dest"
}

verify_daemon_config() {
    [ -f /etc/docker/daemon.json ] \
        && grep -q '"storage-driver": "vfs"' /etc/docker/daemon.json \
        && grep -q '"iptables": false' /etc/docker/daemon.json \
        && grep -q '"bridge": "none"' /etc/docker/daemon.json
}

#==============================================================================
# Step 3: Start containerd (must be running before dockerd)
#==============================================================================

start_containerd() {
    if [ ! -f /usr/bin/containerd ]; then
        echo "containerd binary not found"
        return 1
    fi

    sudo containerd >/tmp/containerd.log 2>&1 &
    echo "containerd starting (PID: $!)"

    for i in $(seq 1 10); do
        if sudo ctr version >/dev/null 2>&1; then
            echo "containerd ready"
            return 0
        fi
        sleep 1
    done

    echo "containerd did not become ready within 10s"
    return 1
}

verify_containerd_running() {
    pgrep -x containerd >/dev/null && sudo ctr version >/dev/null 2>&1
}

#==============================================================================
# Step 4: Start dockerd
#==============================================================================

start_dockerd() {
    if [ ! -f /usr/bin/dockerd ]; then
        echo "dockerd binary not found"
        return 1
    fi

    sudo /usr/bin/dockerd >/tmp/dockerd.log 2>&1 &
    echo "dockerd starting (PID: $!)"

    for i in $(seq 1 20); do
        if sudo docker info >/dev/null 2>&1; then
            echo "dockerd ready"
            return 0
        fi
        sleep 1
    done

    echo "dockerd did not become ready within 20s"
    return 1
}

verify_dockerd_running() {
    pgrep -x dockerd >/dev/null && docker info >/dev/null 2>&1
}

#==============================================================================
# Step 5: Fix socket permissions
#==============================================================================

fix_socket_permissions() {
    if [ -S /var/run/docker.sock ]; then
        sudo chmod 666 /var/run/docker.sock
        echo "Socket permissions set to 666"
    else
        echo "Docker socket not found"
        return 1
    fi
}

verify_socket_accessible() {
    docker ps >/dev/null 2>&1
}

#==============================================================================
# Step 6: Verify VFS storage driver is active
#==============================================================================

verify_vfs_active() {
    local driver
    driver=$(docker info 2>/dev/null | grep 'Storage Driver' | awk '{print $3}')
    [ "$driver" = "vfs" ]
}

#==============================================================================
# Main: execute-then-verify for each step
#==============================================================================

main() {
    # Cleanup
    cleanup_stale_processes

    # Install
    install_docker || { echo "FATAL: Docker installation failed"; exit 1; }
    verify_or_fail "docker installed" verify_docker_installed || exit 1

    # Configure
    apply_daemon_config || echo "Warning: daemon config issue"
    verify_or_fail "daemon config applied" verify_daemon_config || echo "Warning: config verification failed"

    # Start containerd first, then dockerd
    start_containerd || echo "Warning: containerd startup issue"
    verify_or_fail "containerd running" verify_containerd_running || echo "Warning: containerd not verified"

    start_dockerd || { echo "FATAL: dockerd failed to start"; exit 1; }
    verify_or_fail "dockerd running" verify_dockerd_running || exit 1

    # Permissions
    fix_socket_permissions || echo "Warning: socket permission issue"
    verify_or_fail "socket accessible without sudo" verify_socket_accessible || echo "Warning: socket access issue"

    # VFS
    verify_or_fail "VFS storage driver active" verify_vfs_active || echo "Warning: VFS not active"

    # Docker Compose
    if docker compose version >/dev/null 2>&1; then
        echo "PASS: Docker Compose available ($(docker compose version))"
    else
        echo "Warning: Docker Compose not available"
    fi

    echo ""
    echo "=== Installation complete ==="
    echo "Run devcontainer/verify_environment.sh for health checks"
}

main
