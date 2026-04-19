# JetBrains Dev Containers for `you-todoo`

This repository supports two development modes:

- **local**: the repository stays on the host machine and is mounted into the dev container
- **isolated**: the repository is cloned into an isolated Docker-backed workspace created from a generated dev container config

This document explains the setup, the tradeoffs, the Docker socket quirks, the user/permission quirks, and the throwaway generator flow.

---

# 1. Terminology

## Local
Previously called "external".

This means:

- the Git repo exists on your host filesystem
- JetBrains connects to a dev container
- the project is visible inside the dev container under `/workspace/you-todoo`
- edits are happening against your host checkout

Host path example:

```text
/home/matej/projects/private/bymatej/you-todoo
```

Container path example:

```
/workspace/you-todoo
```

So in local mode, those are the **same project files**, just seen from two different places.

## Isolated

Previously called "throwaway".

This means:

- JetBrains starts a dedicated dev container from a generated `devcontainer.json`
- the workspace is isolated from the host project checkout
- the code is cloned into the isolated environment after the container starts
- the isolated environment can be created multiple times with different names

This is meant for experimental, disposable, sandbox-like workspaces.

---

# 2. What this setup is trying to achieve

The goal is to support both of these workflows:

## Local workflow

Use one stable project checkout on the host, but do development inside a reproducible Dockerized environment.

Good for:

- regular day-to-day development
- editing from JetBrains
- using the host checkout as the single main source tree

## Isolated workflow

Spin up named isolated workspaces such as:

- `test1`
- `test2`
- `refactor-auth`
- `bugfix-api`

Each isolated environment should have:

- its own containerized development environment
- its own independent cloned workspace
- the ability to be created again from a generator script

---

# 3. Big picture architecture

This repo uses:

- one shared `.devcontainer/Dockerfile`
- one local `devcontainer.json`
- one isolated template `throwaway.template.json`
- one generator script `make-throwaway.sh`

The generator script creates a **directory per isolated workspace**, and inside each directory it creates a file named exactly:

```
devcontainer.json
```

This is important because JetBrains expects that exact file name.

---

# 4. Repository layout

Expected layout:

```
you-todoo/
├── application/
├── Dockerfile                       # runtime Dockerfile for the app itself
├── .devcontainer/
│   ├── Dockerfile                   # dev environment Dockerfile
│   ├── devcontainer.json            # local mode config
│   ├── throwaway.template.json      # isolated template
│   ├── make-throwaway.sh            # generator script
│   └── generated/
│       ├── .gitignore
│       ├── test1/
│       │   └── devcontainer.json
│       └── test2/
│           └── devcontainer.json
└── ...
```

---

# 5. Local mode: how it works

The local mode is defined by:

```
.devcontainer/devcontainer.json
```

It uses:

- the shared `.devcontainer/Dockerfile`
- the host project checkout as the workspace
- a non-root user matching the current host user
- the host Docker socket mounted into the dev container
- a runtime `--group-add` so the current user can talk to the Docker socket

## Why local mode uses a non-root user

If local mode runs as `root`, then any file created from the dev container becomes owned by `root` on the host.

Example bad result:

```
-rw-r--r-- 1 root root 4 Apr 20 00:18 test.txt
```

That is unacceptable for normal bind-mounted local development.

So in local mode, the dev container should run as the current host-like user, not as `root`.

---

# 6. Isolated mode: how it works

The isolated mode is defined by generated files such as:

```
.devcontainer/generated/test1/devcontainer.json
.devcontainer/generated/test2/devcontainer.json
```

Each of these is created from:

```
.devcontainer/throwaway.template.json
```

Each generated isolated config:

- gets its own unique name
- gets its own unique workspace storage
- clones the repo into `/workspace/you-todoo`
- can optionally use the Docker socket too

## Why isolated mode uses `root`

For isolated workspaces, using `root` is acceptable and often simpler.

Reason:

- there is no bind-mounted host project checkout to pollute
- the isolated workspace is not the host repo
- root-owned files inside the isolated environment are not a host-side ownership problem

Also, isolated workspaces may need to create/populate their own workspace directories and clone the repo there. Running as `root` avoids common volume ownership problems during initial bootstrap.

So the user strategy is intentionally different:

| Mode | Recommended user |
| --- | --- |
| local | current non-root user |
| isolated | `root` |

---

# 7. Dev Dockerfile vs runtime Dockerfile

There are two different Dockerfiles in this repo:

## Root `Dockerfile`

This is the app/runtime Dockerfile.

It is used for:

- building the app container
- runtime execution
- production-style image behavior

It is **not** the right Dockerfile for the IDE development environment.

## `.devcontainer/Dockerfile`

This is the development environment Dockerfile.

It is used for:

- Python tooling
- shell tools
- Git
- Docker CLI / Compose plugin
- JetBrains dev container backend

It is **not** the app runtime image.

This split is deliberate and necessary.

---

# 8. Docker access from inside the dev container

By default, a JetBrains dev container does **not** automatically have Docker access.

That means:

- `docker ps` may fail
- PyCharm Docker run configs may fail
- `docker compose` may fail
- multi-service development becomes painful

To fix that, this setup mounts the host Docker socket into the dev container:

```json
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
]
```

But that alone is not enough.

---

# 9. Docker socket permission problem

The Docker socket on the host is typically owned like this:

```
srw-rw---- 1 root 984 ... /var/run/docker.sock
```

That means:

- owner: `root`
- group: Docker-related group, for example GID `984`
- permissions: `660`

So if the dev container runs as a non-root user, that user must also be in the socket’s group.

This is why local mode needs:

```json
"runArgs": [
  "--group-add",
  "${localEnv:DOCKER_GID}"
]
```

This is a **runtime** fix, not just an image build fix.

## Why `usermod -aG ...` in the Dockerfile was not enough

Adding the group during image build alone was not sufficient in practice for this JetBrains dev container workflow.

The effective fix was adding the socket GID at container runtime with:

```json
"runArgs": [
  "--group-add",
  "${localEnv:DOCKER_GID}"
]
```

That is the important part.

---

# 10. This is not true Docker-in-Docker

This setup does **not** run a full Docker daemon inside the dev container.

Instead, it uses:

- Docker CLI inside the dev container
- the host’s Docker daemon through `/var/run/docker.sock`

So it is more accurately:

- Docker socket passthrough
- Docker-from-inside-the-container-via-host-daemon

This is often casually called Docker-in-Docker, but technically it is not.

Still, for practical development purposes, it gives the effect most people want:

- `docker ps`
- `docker build`
- `docker compose up`
- PyCharm Docker-related actions can work more realistically

---

# 11. Launching JetBrains with required environment variables

Because the devcontainer config uses things like:

```json
"${localEnv:USER}"
"${localEnv:UID}"
"${localEnv:GID}"
"${localEnv:DOCKER_GID}"
```

the application that launches the dev container must have those variables in its environment.

That means:

- if PyCharm launches the dev container, PyCharm must inherit them
- if JetBrains Gateway launches the dev container, Gateway must inherit them

## Required shell export

Before launching PyCharm or Gateway:

```bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
```

Then launch the JetBrains app from that same shell.

Example:

```bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
pycharm
```

or

```bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
jetbrains-gateway
```

## Important note

If you launch JetBrains from a desktop icon or app menu without these exported variables, the dev container may not receive the correct values.

That leads to confusing failures such as:

- wrong user setup
- no Docker socket access
- inconsistent local vs Gateway behavior

---

# 12. `.desktop` launcher hint

If you want PyCharm or Gateway launched from a desktop icon to inherit these variables, the clean approach is to use a wrapper script.

Example wrapper script:

```bash
#!/usr/bin/env bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
exec "/path/to/pycharm" "$@"
```

Then point the `.desktop` file’s `Exec=` at that wrapper.

This avoids having to remember to launch the app from a terminal every time.

---

# 13. Local mode file ownership quirk

If you run local mode as `root`, files created in the dev container will show up on the host as root-owned.

Example:

```
-rw-r--r-- 1 root root 4 Apr 20 00:18 test.txt
```

## Fix

Use a non-root current-user setup in local mode.

If you already created root-owned files, fix them on the host:

```bash
sudo chown -R matej:matej /home/matej/projects/private/bymatej/you-todoo
```

Be careful with recursive ownership fixes if there are files you do not want to touch.

---

# 14. Isolated mode workspace quirk

An isolated workspace initially came up empty because the workspace directory existed but was root-owned and the non-root user could not populate it.

Example symptom:

```
/workspace/you-todoo
total 8.0K
drwxr-xr-x 2 root root 4.0K ...
```

and no code inside.

## Fix

Use `root` for isolated mode so it can initialize the isolated workspace cleanly and perform the clone.

Because isolated mode is not bind-mounting the host repo, this is acceptable.

---

# 15. Why isolated configs must be generated into directories

JetBrains expects the selected file to be literally called:

```
devcontainer.json
```

So generating files like:

```
throwaway-test1.json
throwaway-test2.json
```

does not fit the tool well.

The correct generator output shape is:

```
.devcontainer/generated/test1/devcontainer.json
.devcontainer/generated/test2/devcontainer.json
```

That is why the generator script creates a directory per isolated workspace.

---

# 16. Relative path quirks in generated configs

The generated isolated configs live deeper in the tree:

```
.devcontainer/generated/test1/devcontainer.json
```

So relative paths in those generated configs are different from the local config.

## Local config

File location:

```
.devcontainer/devcontainer.json
```

Correct build paths:

```json
"dockerfile": "Dockerfile",
"context": ".."
```

## Generated isolated config

File location:

```
.devcontainer/generated/test1/devcontainer.json
```

Correct build paths:

```json
"dockerfile": "../../Dockerfile",
"context": "../../.."
```

This is easy to get wrong.

If these paths are wrong, JetBrains creation fails with errors like:

```
failed to read dockerfile: open Dockerfile: no such file or directory
```

or Docker build context problems like missing:

```
application/requirements.txt
```

---

# 17. Generator script overview

The generator script:

```
.devcontainer/make-throwaway.sh
```

takes one argument:

```bash
./.devcontainer/make-throwaway.sh test1
```

and creates:

```
.devcontainer/generated/test1/devcontainer.json
```

It sanitizes the name and substitutes it into the isolated template.

## Example

Generate two isolated environments:

```bash
./.devcontainer/make-throwaway.sh test1
./.devcontainer/make-throwaway.sh test2
```

Verify:

```bash
find .devcontainer/generated -maxdepth 3 -type f
```

Expected result:

```
.devcontainer/generated/test1/devcontainer.json
.devcontainer/generated/test2/devcontainer.json
```

---

# 18. Recommended current files

## `.devcontainer/Dockerfile`

This file should define the development environment, install Docker CLI and Compose plugin, and create the current-user-like account.

## `.devcontainer/devcontainer.json`

This file should define the **local** mode, including:

- current user
- Docker socket mount
- `runArgs --group-add`

## `.devcontainer/throwaway.template.json`

This file should define the **isolated** template, including:

- `root` user
- Docker socket mount if needed
- correct deep relative paths
- clone logic in `postCreateCommand`

## `.devcontainer/make-throwaway.sh`

This file should generate:

```
.devcontainer/generated/<name>/devcontainer.json
```

---

# 19. Why local and isolated intentionally differ

This is not accidental. These modes have different constraints.

## Local mode constraints

- must not create root-owned files on the host
- should behave like normal editable mounted development
- should use a host-like user
- still needs Docker socket access

## Isolated mode constraints

- does not bind-mount the host repo
- must be able to bootstrap its own workspace
- can tolerate running as `root`
- is intended more as a disposable sandbox

Trying to force both modes into the exact same user model causes pain.

So the split is intentional and practical.

---

# 20. How to create a local environment

1.  Start JetBrains with exported vars:

```bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
pycharm
```

or

```bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
jetbrains-gateway
```

2.  Use the local config:

```
/home/matej/projects/private/bymatej/you-todoo/.devcontainer/devcontainer.json
```

3.  Create the dev container.

4.  Open the project.

5.  Verify inside the dev container:

```bash
id
ls -l /var/run/docker.sock
docker ps
docker compose version
```

Expected behavior:

- current user is not root
- Docker socket is mounted
- `docker ps` works

---

# 21. How to create isolated environments

## Generate

From repo root:

```bash
./.devcontainer/make-throwaway.sh test1
./.devcontainer/make-throwaway.sh test2
```

## Result

This should create:

```
.devcontainer/generated/test1/devcontainer.json
.devcontainer/generated/test2/devcontainer.json
```

## In JetBrains Gateway or PyCharm

Create a dev container using one of these exact generated files:

```
/home/matej/projects/private/bymatej/you-todoo/.devcontainer/generated/test1/devcontainer.json
/home/matej/projects/private/bymatej/you-todoo/.devcontainer/generated/test2/devcontainer.json
```

## Verify inside isolated environment

```bash
pwd
id
docker ps
ls -lah /workspace/you-todoo
git status
```

Expected behavior:

- running as `root` or root-effective isolated setup
- workspace contains a cloned repo
- host repo is not the isolated workspace

---

# 22. Testing the runtime image from inside local mode

Once Docker socket access works, local mode can also build and run the app runtime container.

Example inside the local dev container:

```bash
docker build -t you-todoo-runtime -f Dockerfile .
docker run --rm -p 5000:5000 you-todoo-runtime
```

Then test from the host:

```
http://localhost:5000
```

## Important note

If your run configuration starts a container but you cannot access the app, check whether port `5000` is actually published.

Bad:

```
5000/tcp
```

Good:

```
0.0.0.0:5000->5000/tcp
```

---

# 23. Why PyCharm Services view may disagree with `docker ps`

This happened during development.

Sometimes:

- `docker ps` inside the dev container shows running containers
- but the JetBrains Services panel does not show them properly

This appears to be a JetBrains Docker/remote-backend integration quirk.

## Practical advice

When in doubt, trust:

```bash
docker ps
docker logs -f <container>
```

more than the UI.

---

# 24. Known tradeoffs

## Pros

- reproducible development environment
- Dockerized editor/runtime tooling
- clear split between local and isolated workflows
- isolated workspaces can be generated on demand
- Docker access from inside the dev container is possible

## Cons

- relative paths are fragile
- environment variables must be passed into the launcher process
- local mode needs careful non-root plus socket-group handling
- isolated mode is simpler with `root`
- JetBrains UI behavior is sometimes inconsistent with `docker ps`
- generated configs must be laid out in a JetBrains-friendly way

---

# 25. Summary of user strategy

## Local

Use the current user, not `root`.

Reason:

- avoids root-owned files in the host checkout

## Isolated

Use `root`.

Reason:

- avoids isolated workspace bootstrap permission issues
- no host bind-mounted repo to pollute

## Docker access

Use mounted host Docker socket plus runtime group-add.

Reason:

- enables Docker/Compose use inside local dev container
- avoids needing full Docker-in-Docker

---

# 26. Troubleshooting

## Symptom: created files on host are owned by root

Cause:

- local mode ran as `root`

Fix:

- switch local mode back to current user
- rebuild the dev container
- fix host ownership with `chown` if needed

## Symptom: `Permission denied` on `/var/run/docker.sock`

Cause:

- current user is not in the socket group

Fix:

- ensure `DOCKER_GID` is exported before launching JetBrains
- ensure `runArgs` includes:

    ```json
    "--group-add", "${localEnv:DOCKER_GID}"
    ```

- rebuild the container fully

## Symptom: `failed to read dockerfile: open Dockerfile: no such file or directory`

Cause:

- wrong relative paths in generated isolated config

Fix:

- for generated isolated configs, use:

    ```json
    "dockerfile": "../../Dockerfile",
    "context": "../../.."
    ```

## Symptom: isolated workspace has no code

Cause:

- workspace bootstrap failed, often due to permissions

Fix:

- use `root` for isolated mode
- recreate the isolated environment

## Symptom: JetBrains cannot distinguish multiple isolated configs

Cause:

- generated files were not named `devcontainer.json`

Fix:

- generate:

    ```
    .devcontainer/generated/<name>/devcontainer.json
    ```

---

# 27. Recommended operational routine

## Local routine

- launch JetBrains with exported vars
- open local dev container
- edit code against the host checkout
- use Docker from inside when needed

## Isolated routine

- generate new isolated config
- create isolated dev container from generated file
- experiment in isolation
- push or discard as needed

---

# 28. Final practical conclusion

This setup works best when treated as two intentionally different modes:

## Local

Stable, user-safe, host-backed, day-to-day environment.

## Isolated

Disposable, root-friendly, self-bootstrap sandbox environment.

Trying to force them into one identical configuration causes unnecessary pain.

The current structure is opinionated, but it reflects the real quirks discovered during setup:

- local bind mounts hate `root`
- isolated bootstrap hates unnecessary non-root friction
- Docker socket access needs runtime group handling
- JetBrains wants `devcontainer.json`, not arbitrary filenames
- generated configs need different relative paths than the top-level local config

That is the design this repository now uses.