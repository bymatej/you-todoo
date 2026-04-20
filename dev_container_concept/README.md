# JetBrains Dev Containers for `you-todoo`

This repository has two Dev Container modes:

- **Local mode**: the host checkout is mounted into the dev container. This is the normal day-to-day workflow.
- **Throwaway mode**: the repository is cloned into Docker-managed storage. Changes do not leak back to the host checkout.

Both modes use `.devcontainer/Dockerfile` for the workspace image and a `docker:dind` sidecar for Docker access from inside the workspace.

---

# 1. Local Mode

Local mode is defined by:

```text
.devcontainer/devcontainer.json
.devcontainer/docker-compose.local.yml
```

The workspace service bind-mounts the host repository:

```yaml
volumes:
  - ..:/workspace/you-todoo
```

That is intentional. Files edited inside the container and files edited on the host are the same files.

Local mode should run as a non-root host-like user. Running local mode as `root` can create root-owned files in the host checkout.

The local Docker sidecar publishes the normal app port:

```yaml
ports:
  - "5000:5000"
```

When an app container is started inside the inner Docker daemon, host browser access requires this outer sidecar port mapping.

Open the local app on:

```text
http://localhost:5000
```

---

# 2. Throwaway Mode

Create a throwaway config with:

```bash
./.devcontainer/make-throwaway.sh <name> [app-port]
```

Examples:

```bash
./.devcontainer/make-throwaway.sh hotfix1
./.devcontainer/make-throwaway.sh hotfix2
./.devcontainer/make-throwaway.sh hotfix3 5503
```

If no app port is supplied, the generator picks the first free port from `5101` through `5199`. It skips ports already used by generated throwaway configs and ports currently listening on the host.

You can change the auto-pick range:

```bash
THROWAWAY_PORT_BASE=5201 THROWAWAY_PORT_MAX=5299 ./.devcontainer/make-throwaway.sh hotfix4
```

Each generated throwaway gets:

```text
.devcontainer/generated/<name>/devcontainer.json
.devcontainer/generated/<name>/docker-compose.yml
```

Use the generated `devcontainer.json` when creating the JetBrains Dev Container.

---

# 3. Throwaway Isolation

Throwaway mode must not bind-mount the host checkout.

The generated `devcontainer.json` explicitly controls the workspace mount:

```json
"workspaceMount": "source=you-todoo-throwaway-<name>,target=/workspace,type=volume",
"workspaceFolder": "/workspace/you-todoo",
"remoteUser": "dev",
"updateRemoteUserUID": false
```

The generated Compose file intentionally does **not** mount `/workspace`. That is left to `workspaceMount`, so JetBrains does not infer a host source bind mount from the local project path.

The repository is cloned into the named volume by lifecycle commands:

```bash
sudo mkdir -p /workspace/you-todoo && sudo chown -R dev:dev /workspace && if [ ! -d /workspace/you-todoo/.git ] && [ -z "$(ls -A /workspace/you-todoo 2>/dev/null)" ]; then git clone https://github.com/bymatej/you-todoo.git /workspace/you-todoo; fi
```

This command is used for both `postCreateCommand` and `postStartCommand`, so an empty throwaway workspace can recover if the first create pass did not clone.

The `sudo chown` is deliberate. A fresh Docker volume mounted at `/workspace` can appear as `root:root`, even though the image pre-creates `/workspace`. The lifecycle command repairs that before cloning as `dev`.

---

# 4. Throwaway Ports

Throwaway mode uses nested Docker:

```text
host browser
  -> outer docker:dind sidecar port
    -> inner Docker app container published port
      -> app port 5000
```

The generator prints the selected port and the PyCharm binding to use.

Example output:

```text
App port: 5102
Use inner Docker/PyCharm port binding: 0.0.0.0:5102:5000
Open on host: http://localhost:5102
```

For that throwaway, configure the PyCharm Docker run config with:

```text
0.0.0.0:5102:5000
```

Then open:

```text
http://localhost:5102
```

Docker cannot publish arbitrary future inner-Docker ports from an already-created outer sidecar. The host-facing port must be known when the throwaway Compose stack is created.

For several throwaways, use the generated ports:

```text
hotfix1 -> http://localhost:5101
hotfix2 -> http://localhost:5102
hotfix3 -> http://localhost:5103
```

---

# 5. Docker Sidecar Model

Both modes use:

```text
DOCKER_HOST=tcp://docker:2375
```

The sidecar is:

```yaml
docker:
  image: docker:27-dind
  privileged: true
  environment:
    DOCKER_TLS_CERTDIR: ""
  command: ["dockerd", "--host=tcp://0.0.0.0:2375"]
```

This avoids mounting `/var/run/docker.sock` from the host into the workspace container.

The tradeoff is port forwarding: host browser access to app containers requires explicit ports on the outer `docker:dind` sidecar.

---

# 6. User And Ownership

The development image creates a configurable user, normally `dev` with UID/GID `1000`.

The image installs `sudo` and grants the generated dev user passwordless sudo inside the dev container. Throwaway lifecycle commands need this because they run as `dev`, while a freshly mounted Docker volume may initially be owned by `root`.

Expected users:

| Mode | User | Reason |
| --- | --- | --- |
| Local | Host-like non-root user | Prevent root-owned files in the host checkout |
| Throwaway | `dev` | Avoid Git dubious-ownership warnings and keep the isolated workspace non-root |

---

# 7. Verification

In local mode:

```bash
pwd
id
mount | grep /workspace
docker ps
git status
```

Expected:

- `/workspace/you-todoo` is the host checkout bind mount.
- The user is non-root.
- `docker ps` talks to the sidecar daemon.
- Files created in the workspace appear on the host with the host user's ownership.

In throwaway mode:

```bash
pwd
id
findmnt /workspace
git status
touch throwaway-check.txt
```

Expected:

- `/workspace` is Docker-managed storage, not the host checkout.
- The user is `dev`.
- `git status` does not fail with dubious ownership.
- `throwaway-check.txt` does not appear in the host checkout.

---

# 8. Cleanup

Stop the generated Dev Container from JetBrains, then remove the named volumes if you want to discard throwaway state:

```bash
docker volume rm you-todoo-throwaway-<name>
docker volume rm you-todoo-throwaway-<name>-dind
```

Use the actual generated name after sanitization.
