FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# System dependencies needed by Cursor agents: git, bash, curl, sudo, ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    git bash curl sudo ca-certificates procps \
    && rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo.
# Acceptable for ephemeral, single-user dev containers.
RUN useradd -ms /bin/bash devagent \
    && mkdir -p /home/devagent \
    && chown devagent:devagent /home/devagent \
    && echo "devagent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devagent \
    && chmod 0440 /etc/sudoers.d/devagent

USER devagent
WORKDIR /home/devagent

ENV PATH="$PATH:/home/devagent/.local/bin"
RUN python -m pip install --user --upgrade pip

# Keep container alive for Cursor to attach
CMD ["bash", "-ilc", "sleep infinity"]
