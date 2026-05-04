#!/usr/bin/env bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug

################################################################################
#READ THE COMMENTS BEFORE RUNNING
#-https://www.simple-help.com
#File:      docker_dhcpd_install.sh
#Date:      2022NOV29
#Author:    William Blair
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11, MX 21
#Arch:      amd_64
#
#This script will create a simple-help server
#- TODO:
################################################################################
IMAGE_SOURCE="debian:11-slim"
IMAGE_NAME="simple-help:5.4.5"
COMPOSE_FILE="docker-compose.yaml"
docker pull "$IMAGE_SOURCE"
#---------------------------------------------------------------------------------

#MTU issue forces us to download outside of image and COPY 
#it over..send me a message if you know how to change the
#MTU of a newly created network..
#wget https://simple-help.com/releases/SimpleHelp-linux-amd64.tar.gz
#wget https://simple-help.com/releases/5.2.17/SimpleHelp-linux-amd64.tar.gz
#---------------------------------------------------------------------------------

#generate DOCKERFILE
cat > Dockerfile << EOF
FROM $IMAGE_SOURCE

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet --quiet --yes update
RUN apt-get --quiet --quiet --yes --no-install-recommends \
    --option "DPkg::Options::=--force-confold" \
    --option "DPkg::Options::=--force-confdef" \
    install apt-utils ca-certificates wget
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

WORKDIR /opt
#Uncomment next line for new installations
RUN wget --no-verbose https://simple-help.com/releases/SimpleHelp-linux-amd64.tar.gz
#RUN wget https://simple-help.com/releases/5.2.17/SimpleHelp-linux-amd64.tar.gz

RUN tar -xzf SimpleHelp-linux-amd64.tar.gz && rm SimpleHelp-linux-amd64.tar.gz

WORKDIR /opt/SimpleHelp
RUN sed -i 's/&//g' serverstart.sh

CMD ["sh", "serverstart.sh"]
#use this to run container forever if you need to troubleshoot
#CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
EOF
#---------------------------------------------------------------------------------

docker build --tag "$IMAGE_NAME" .

#for local registry
#docker tag "$IMAGE_NAME" localhost:5000/"$IMAGE_NAME"
#docker push localhost:5000/"$IMAGE_NAME"
#---------------------------------------------------------------------------------

#generate docker-compose file
cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
    simple-help:
        #image: localhost:5000/simple-help:5.4.5
        image: simple-help:5.4.5
        restart: unless-stopped
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - ./shlicense.txt:/opt/SimpleHelp/shlicense.txt:rw
            #uncomment if you're move existing install to another server or
            #when you get server setup properly then you can copy from the 
            #container to the host for backup & easy migration purposes. Like this:
            #docker cp <container_name>:/opt/SimpleHelp <host_directory>/SimpleHelp
            #- ./SimpleHelp:/opt/SimpleHelp:rw
            
        stdin_open: true # docker run -i
        tty: true        # docker run -t
EOF
#---------------------------------------------------------------------------------
