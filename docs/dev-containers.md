# Dev Containers

## Philosophy

Agents should be able to do everything a human developer can do. This means running inside a container that has:

- Docker and Docker Compose (to run and test multi-service applications)
- Git (to commit, branch, push)
- Network access (to reach CI/CD, APIs, package registries)
- The project's full dependency stack

Without these capabilities, agents are limited to editing files and hoping the CI catches problems. With them, agents can run the app, verify behavior, debug failures, and iterate -- the same loop a human developer follows.


## The full containerized stack

The longer-term goal goes beyond Docker-in-Docker for a single agent. The entire development environment -- model routing proxy, voice pipeline services, agent containers, application services -- should be expressible as a Docker Compose configuration. Spin it up on any machine and get a working environment.

This means the model router (LiteLLM or equivalent), any local model servers, the voice STT/TTS services, and the agent orchestration layer all run as containers that can talk to each other. The developer's machine just runs Docker and the voice input app. Everything else is inside the compose stack, reproducible across machines.


## Docker-in-Docker

Running Docker inside a Docker container is the key technical challenge. The agent's container needs to launch and manage other containers (the application's services).

### The VFS solution

In many cloud-hosted container environments (e.g., Cursor cloud agents), the host filesystem uses overlayfs. Docker's default storage driver (overlay2) cannot run on top of overlayfs -- you get nested overlay errors.

The solution is the VFS storage driver, which makes full filesystem copies instead of using copy-on-write layers.

Docker daemon configuration (`daemon.json`):
```json
{
  "storage-driver": "vfs",
  "iptables": false,
  "bridge": "none"
}
```

Why each setting:
- **`storage-driver: vfs`**: Avoids the nested overlayfs problem. Trade-off: ~2x disk usage, ~60-70% speed. Acceptable for development containers.
- **`iptables: false`**: Many container sandboxes restrict iptables manipulation. Disabling it avoids permission errors.
- **`bridge: none`**: Bridge networking requires iptables. With bridge disabled, use `network_mode: host` for inter-service communication via localhost.

### Container architecture

```
Host (macOS with OrbStack or similar)
  └── Agent container (the dev environment)
        ├── dockerd (running with VFS driver)
        └── Application containers (via docker-compose)
              ├── API service
              ├── Web service
              ├── Database
              └── Other services
```

### Install and verify pattern

The container setup follows an execute-then-verify pattern. Every installation step has a paired verification function:

1. `install_docker` -> `verify_docker_installed`
2. `apply_daemon_config` -> `verify_daemon_config`
3. `start_containerd` -> `verify_containerd_running` (must start before dockerd)
4. `start_dockerd` -> `verify_dockerd_running`
5. `fix_socket_permissions` -> `verify_socket_permissions`

Verification functions are collected in a shared library (only function definitions, never auto-executing). Multiple scripts source this library:
- **install.sh**: Runs at container build time. Executes all steps with verification.
- **verify_environment.sh**: Read-only health check. Runs verification functions without executing setup steps. Fast (~20s).
- **test_capabilities.sh**: Full integration test. Pulls images, runs containers, tests networking. Slower (~60-90s).

### Socket permissions

A common gotcha: the Docker socket (`/var/run/docker.sock`) needs to be accessible to the agent user. After testing many approaches (usermod, newgrp, daemon group config), the simplest reliable solution is:

```bash
sudo chmod 666 /var/run/docker.sock
```

Run this at container start time. It's acceptable for ephemeral dev containers where security isolation between users isn't a concern.


## Local development with OrbStack

For local development (not cloud-hosted agents), OrbStack is preferred over Docker Desktop. It's lighter weight, starts faster, and uses fewer resources. Colima is another option for developers who prefer a CLI-only Docker runtime.

The container configuration should work with any Docker-compatible runtime. Avoid runtime-specific features where possible.


## Dockerfile template

A minimal agent container:

```dockerfile
FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y \
    git bash curl sudo ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create agent user with sudo access (acceptable for ephemeral dev containers)
RUN useradd -m -s /bin/bash devagent \
    && echo "devagent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER devagent
WORKDIR /workspace

CMD ["sleep", "infinity"]
```

The Docker and Docker Compose installation happens via an install script at build time, not at runtime. This ensures the agent has a working Docker environment immediately when it starts.


## CI integration

The dev container should have access to CI/CD systems (CircleCI, GitHub Actions, etc.) so agents can:

- Monitor build status after pushing changes
- Read test output to diagnose failures
- Understand the CI pipeline configuration

This typically means providing API tokens as environment variables and including helper scripts that wrap CI API calls into simple commands agents can use.

A CI helper pattern that works well: a Python script with subcommands like `smart-monitor <commit>` (poll until build finishes, report results) and `debug <build_number>` (fetch full console output for a failed build).

CI monitoring must be non-blocking. An agent waiting for a build should not hold up the developer's conversational thread. Run CI monitoring in the background and surface results when they arrive.
