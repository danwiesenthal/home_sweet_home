# devcontainer/

Configuration files for running Cursor cloud background agents with Docker-in-Docker support.

## What this is

When Cursor spawns a background agent, it runs inside a cloud VM. These files configure that VM so the agent has a working Docker environment -- meaning it can build images, run `docker compose`, and test the full application stack, just like a human developer.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Base image: Python 3.12, git, bash, curl, sudo. Non-root user with passwordless sudo. |
| `daemon.json` | Docker daemon config. VFS storage driver (avoids nested overlayfs), iptables disabled, bridge disabled. |
| `install.sh` | Installs Docker + Docker Compose, applies daemon config, starts containerd then dockerd. Every step is verified before proceeding. |
| `environment.json` | Cursor environment config. Tells Cursor how to build, install, and start the container. |
| `verify_environment.sh` | Read-only health check. Verifies Docker is installed, configured, and running. No side effects. |

## How to use

### For Cursor background agents

Copy `environment.json` to `.cursor/environment.json` in your repo root (Cursor looks for it there):

```bash
cp devcontainer/environment.json .cursor/environment.json
```

Then update the paths in `.cursor/environment.json` to point at the devcontainer files:

```json
{
  "build": {
    "dockerfile": "../devcontainer/Dockerfile",
    "context": "../devcontainer"
  },
  "install": "devcontainer/install.sh",
  "start": "sudo chmod 666 /var/run/docker.sock 2>/dev/null || true",
  "terminals": [
    {
      "name": "Shell",
      "command": "cd /workspace && bash"
    }
  ]
}
```

Or copy the Dockerfile and other files into `.cursor/` directly -- whatever suits your repo layout.

### Health check

After the agent boots, verify the environment:

```bash
./devcontainer/verify_environment.sh
```

Returns exit code 0 if everything is healthy.

## Key design decisions

**VFS storage driver**: Cloud VMs typically use overlayfs for the host filesystem. Docker's default overlay2 driver can't nest on top of overlayfs. VFS makes full copies instead. Slower and uses more disk, but it works reliably.

**No iptables, no bridge**: Container sandboxes restrict iptables. Bridge networking needs iptables. Disable both and use `network_mode: host` in compose files instead.

**containerd before dockerd**: dockerd depends on containerd. The install script starts containerd first and waits for it to be responsive before launching dockerd.

**Socket permissions**: `chmod 666 /var/run/docker.sock` runs at start time. Acceptable for ephemeral single-user dev containers. Not appropriate for shared or production environments.

**Execute-then-verify**: Every installation step has a paired verification check. If a step fails, the script reports it immediately rather than silently proceeding with a broken environment.
