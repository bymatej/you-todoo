This is the script: 
```shell
#!/usr/bin/env bash
export UID="$(id -u)"
export GID="$(id -g)"
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
exec "/home/matej/.local/share/JetBrains/Toolbox/apps/gateway/bin/gateway" "$@"
```

Put this in an .sh file and run gateway this way. 
Reason: docker (DinD) and permissions (usually requires `root`) and avoiding modifying files from dev container with root user (using current user).
