FROM python:3.12-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update && apt-get install -y \
    git \
    bash \
    curl \
    build-essential \
    ca-certificates \
    gnupg \
    sudo \
 && rm -rf /var/lib/apt/lists/*

# Docker CLI + Compose plugin
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && chmod a+r /etc/apt/keyrings/docker.gpg \
 && echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

# Node.js 20 for Codex CLI and Claude Code
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && chmod a+r /etc/apt/keyrings/nodesource.gpg \
 && echo \
    "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
 && apt-get update \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

# Create dev user
RUN if ! getent group "${USER_GID}" >/dev/null; then \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi \
 && if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" -ms /bin/bash "${USERNAME}"; \
    fi \
 && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# Install agent CLIs globally
RUN npm install -g @openai/codex @anthropic-ai/claude-code \
 && npm cache clean --force

RUN mkdir -p /workspace/you-todoo \
 && chown -R "${USER_UID}:${USER_GID}" /workspace

WORKDIR /workspace/you-todoo

COPY application/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
