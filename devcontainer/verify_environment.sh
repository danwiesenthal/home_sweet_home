#!/usr/bin/env bash
#
# Read-only health check for the dev container Docker environment.
# Does not pull images, run containers, or modify state.
# Expected runtime: ~20 seconds.
#
# Exit code: number of failed checks (0 = all passed).

set +e

echo "=========================================="
echo "Dev Container Environment Verification"
echo "=========================================="
echo ""

failures=0

#==============================================================================
# Level 1: Binaries and processes
#==============================================================================

echo "--- Level 1: Basics ---"

if command -v docker &>/dev/null; then
    echo "PASS: docker binary found"
else
    echo "FAIL: docker binary not found"
    ((failures++))
fi

if docker --version >/dev/null 2>&1; then
    echo "PASS: docker --version responds ($(docker --version))"
else
    echo "FAIL: docker --version failed"
    ((failures++))
fi

if pgrep -x containerd >/dev/null; then
    echo "PASS: containerd process running"
else
    echo "FAIL: containerd process not running"
    ((failures++))
fi

if sudo ctr version >/dev/null 2>&1; then
    echo "PASS: containerd responsive"
else
    echo "FAIL: containerd not responsive"
    ((failures++))
fi

if pgrep -x dockerd >/dev/null; then
    echo "PASS: dockerd process running"
else
    echo "FAIL: dockerd process not running"
    ((failures++))
fi

if docker info >/dev/null 2>&1; then
    echo "PASS: docker daemon responsive"
else
    echo "FAIL: docker daemon not responsive"
    ((failures++))
fi

if [ -S /var/run/docker.sock ]; then
    echo "PASS: docker socket exists"
else
    echo "FAIL: docker socket missing"
    ((failures++))
fi

if docker ps >/dev/null 2>&1; then
    echo "PASS: docker socket accessible without sudo"
else
    echo "FAIL: docker socket not accessible without sudo"
    ((failures++))
fi

# Zombie check
zombie_count=$(ps aux 2>/dev/null | grep -E "docker|containerd" | grep defunct | wc -l)
if [ "$zombie_count" -eq 0 ]; then
    echo "PASS: no zombie docker/containerd processes"
else
    echo "FAIL: found $zombie_count zombie processes"
    ((failures++))
fi

echo ""

#==============================================================================
# Level 2: Configuration
#==============================================================================

echo "--- Level 2: Configuration ---"

if [ -f /etc/docker/daemon.json ]; then
    echo "PASS: daemon.json exists"
else
    echo "FAIL: daemon.json missing at /etc/docker/daemon.json"
    ((failures++))
fi

storage_driver=$(docker info 2>/dev/null | grep 'Storage Driver' | awk '{print $3}')
if [ "$storage_driver" = "vfs" ]; then
    echo "PASS: VFS storage driver active"
else
    echo "FAIL: expected VFS storage driver, got: ${storage_driver:-none}"
    ((failures++))
fi

if grep -q '"iptables": false' /etc/docker/daemon.json 2>/dev/null; then
    echo "PASS: iptables disabled in config"
else
    echo "FAIL: iptables not disabled"
    ((failures++))
fi

if grep -q '"bridge": "none"' /etc/docker/daemon.json 2>/dev/null; then
    echo "PASS: bridge disabled in config"
else
    echo "FAIL: bridge not disabled"
    ((failures++))
fi

echo ""

#==============================================================================
# Level 3: Basic Docker commands
#==============================================================================

echo "--- Level 3: Docker commands ---"

if docker info >/dev/null 2>&1; then
    echo "PASS: docker info works"
else
    echo "FAIL: docker info failed"
    ((failures++))
fi

if docker ps >/dev/null 2>&1; then
    echo "PASS: docker ps works"
else
    echo "FAIL: docker ps failed"
    ((failures++))
fi

if docker compose version >/dev/null 2>&1; then
    echo "PASS: docker compose available ($(docker compose version 2>&1))"
else
    echo "FAIL: docker compose not available"
    ((failures++))
fi

echo ""

#==============================================================================
# Summary
#==============================================================================

echo "=========================================="
if [ $failures -eq 0 ]; then
    echo "ALL CHECKS PASSED"
    echo ""
    echo "Environment is healthy. Docker is configured and running."
else
    echo "FAILED: $failures check(s)"
    echo ""
    echo "Debug:"
    echo "  - Logs: /tmp/dockerd.log, /tmp/containerd.log"
    echo "  - Try: sudo chmod 666 /var/run/docker.sock"
    echo "  - Re-run: devcontainer/install.sh"
fi
echo "=========================================="

exit $failures
