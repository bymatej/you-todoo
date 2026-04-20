#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <name> [app-port]"
  echo "Example: $0 hotfix1 5101"
  exit 1
fi

RAW_NAME="$1"
SAFE_NAME="$(printf '%s' "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"
APP_PORT="${2:-}"
PORT_BASE="${THROWAWAY_PORT_BASE:-5101}"
PORT_MAX="${THROWAWAY_PORT_MAX:-5199}"

if [ -z "$SAFE_NAME" ]; then
  echo "Error: name became empty after sanitization"
  exit 1
fi

case "$PORT_BASE" in
  ''|*[!0-9]*)
    echo "Error: THROWAWAY_PORT_BASE must be a numeric TCP port"
    exit 1
    ;;
esac

case "$PORT_MAX" in
  ''|*[!0-9]*)
    echo "Error: THROWAWAY_PORT_MAX must be a numeric TCP port"
    exit 1
    ;;
esac

if [ "$PORT_BASE" -lt 1 ] || [ "$PORT_BASE" -gt 65535 ] || [ "$PORT_MAX" -lt 1 ] || [ "$PORT_MAX" -gt 65535 ] || [ "$PORT_BASE" -gt "$PORT_MAX" ]; then
  echo "Error: throwaway port range must be within 1..65535 and base must be <= max"
  exit 1
fi

case "$APP_PORT" in
  ''|*[!0-9]*)
    if [ -n "$APP_PORT" ]; then
      echo "Error: app-port must be a numeric TCP port"
      exit 1
    fi
    ;;
esac

if [ -n "$APP_PORT" ] && { [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]; }; then
  echo "Error: app-port must be between 1 and 65535"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/generated/${SAFE_NAME}"

port_in_generated_configs() {
  local port="$1"
  local compose_file

  while IFS= read -r -d '' compose_file; do
    if [ "$compose_file" = "${OUTPUT_DIR}/docker-compose.yml" ]; then
      continue
    fi

    if grep -E '^[[:space:]]*-[[:space:]]*"[0-9]+:[0-9]+"' "$compose_file" 2>/dev/null | grep -q "\"${port}:${port}\""; then
      return 0
    fi
  done < <(find "${SCRIPT_DIR}/generated" -path "*/docker-compose.yml" -type f -print0 2>/dev/null)

  return 1
}

port_listening_on_host() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .
  else
    return 1
  fi
}

if [ -z "$APP_PORT" ]; then
  for candidate in $(seq "$PORT_BASE" "$PORT_MAX"); do
    if ! port_in_generated_configs "$candidate" && ! port_listening_on_host "$candidate"; then
      APP_PORT="$candidate"
      break
    fi
  done

  if [ -z "$APP_PORT" ]; then
    echo "Error: no free app port found in ${PORT_BASE}-${PORT_MAX}"
    echo "Set THROWAWAY_PORT_BASE/THROWAWAY_PORT_MAX or pass a port explicitly."
    exit 1
  fi
else
  if port_in_generated_configs "$APP_PORT"; then
    echo "Error: app-port ${APP_PORT} is already used by a generated throwaway config"
    exit 1
  fi

  if port_listening_on_host "$APP_PORT"; then
    echo "Error: app-port ${APP_PORT} is already listening on the host"
    exit 1
  fi
fi

mkdir -p "${OUTPUT_DIR}"

cat > "${OUTPUT_DIR}/devcontainer.json" <<EOF
{
  "name": "throwaway-you-todoo-${SAFE_NAME}",
  "dockerComposeFile": "docker-compose.yml",
  "service": "workspace",
  "workspaceMount": "source=you-todoo-throwaway-${SAFE_NAME},target=/workspace,type=volume",
  "workspaceFolder": "/workspace/you-todoo",
  "remoteUser": "dev",
  "updateRemoteUserUID": false,
  "shutdownAction": "stopCompose",
  "postCreateCommand": "sudo mkdir -p /workspace/you-todoo && sudo chown -R dev:dev /workspace && if [ ! -d /workspace/you-todoo/.git ] && [ -z \"\$(ls -A /workspace/you-todoo 2>/dev/null)\" ]; then git clone https://github.com/bymatej/you-todoo.git /workspace/you-todoo; fi",
  "postStartCommand": "sudo mkdir -p /workspace/you-todoo && sudo chown -R dev:dev /workspace && if [ ! -d /workspace/you-todoo/.git ] && [ -z \"\$(ls -A /workspace/you-todoo 2>/dev/null)\" ]; then git clone https://github.com/bymatej/you-todoo.git /workspace/you-todoo; fi",
  "customizations": {
    "jetbrains": {
      "backend": "PyCharm"
    }
  }
}
EOF

cat > "${OUTPUT_DIR}/docker-compose.yml" <<EOF
services:
  workspace:
    build:
      context: ../../..
      dockerfile: .devcontainer/Dockerfile
      args:
        USERNAME: dev
        USER_UID: 1000
        USER_GID: 1000
    environment:
      DOCKER_HOST: tcp://docker:2375
      DOCKER_BUILDKIT: "1"
    depends_on:
      - docker
    working_dir: /workspace/you-todoo
    command:
      - /bin/sh
      - -lc
      - mkdir -p /workspace/you-todoo && chown -R 1000:1000 /workspace && sleep infinity

  docker:
    image: docker:27-dind
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: ""
    command: ["dockerd", "--host=tcp://0.0.0.0:2375"]
    ports:
      - "${APP_PORT}:${APP_PORT}"
    volumes:
      - you-todoo-throwaway-${SAFE_NAME}-dind:/var/lib/docker

volumes:
  you-todoo-throwaway-${SAFE_NAME}-dind:
    name: you-todoo-throwaway-${SAFE_NAME}-dind
EOF

echo "Generated: ${OUTPUT_DIR}/devcontainer.json"
echo "Generated: ${OUTPUT_DIR}/docker-compose.yml"
echo "App port: ${APP_PORT}"
echo "Use inner Docker/PyCharm port binding: 0.0.0.0:${APP_PORT}:5000"
echo "Open on host: http://localhost:${APP_PORT}"
