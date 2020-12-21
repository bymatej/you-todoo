FROM ubuntu:20.04

LABEL maintainer="programming@bymatej.com"

ARG DEBIAN_FRONTEND=noninteractive


# Update and install required software and tools
RUN echo "***** Updating and installing required software and tools" && \
    apt -y update && \
    apt -y install python3 \
                   python3-pip \ 
                   python3-dev

# Copy the application and install requirements.txt first to leverage Docker cache
COPY ./application /application/

WORKDIR /application

RUN pip3 install -r requirements.txt

# Expose ports
EXPOSE 5000

ENTRYPOINT [ "python3" ]

CMD [ "app.py" ]
