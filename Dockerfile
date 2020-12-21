FROM ubuntu:20.04

LABEL maintainer="programming@bymatej.com"

ARG DEBIAN_FRONTEND=noninteractive

ENV PYTHONPATH=/you-todoo


# Update and install required software and tools
RUN echo "***** Updating and installing required software and tools" && \
    apt -y update && \
    apt -y install python3 \
                   python3-pip \ 
                   python3-dev

# Copy the application
COPY ./application /you-todoo/application/

WORKDIR /you-todoo

# Install requirements.txt
RUN pip3 install -r /you-todoo/application/requirements.txt

# Set correct python path
#RUN export PYTHONPATH=.

# Expose ports
EXPOSE 5000

# Cleanup
RUN echo "***** Cleaning up" && \
    apt --assume-yes clean && \
    apt --assume-yes autoclean && \
    apt --assume-yes autoremove && \
    rm -rf \
           /tmp/* \
           /var/lib/apt/lists/* \
           /var/tmp/*

ENTRYPOINT [ "python3" ]

CMD [ "application/app.py" ]
