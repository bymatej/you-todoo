# You ToDoo

A small ToDo app based on Flask.

## More information:

- Based on: https://www.youtube.com/watch?v=Z1RJmh_OqeA
- This project was used as a playground to learn more about Flask.
- Original Git Repo: https://github.com/jakerieger/FlaskIntroduction

## Differences from the original app

- different design
- different architecture
- dockerized

# Running

```
docker run -d -p 5000:5000 --name=you-todoo you-todoo bymatej/you-todoo:latest
```

# Features

- ToDo list
- Add new todo
- Display all todos
- Edit entries in todo list
- Remove entries from todo list

There is no authentication. This is just a demo project.

There is no permanent database. The SQLite in-memory DB is used.

# Useful during development

## BUILD & RUN:

```
docker build -t you-todoo . && docker run -d -p 5000:5000 --name=you-todoo you-todoo && docker ps -a 
```

## STOP & REMOVE:

```
docker stop you-todoo && docker rm you-todoo && docker image rm you-todoo
```

## Debug container

1. run the command from the "STOP & REMOVE" section
2. change the end of the Docker file from this:

```
ENTRYPOINT [ "python3" ]

CMD [ "application/app.py" ]
```

to this:

```
#ENTRYPOINT [ "python3" ]

#CMD [ "application/app.py" ]

CMD tail -f /dev/null
```

3. connect to the running container:

```
docker exec -ti you-todoo /bin/bash
```
