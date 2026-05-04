#!/usr/bin/env bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug

################################################################################
#READ THE COMMENTS BEFORE RUNNING
#-https://docs.pyinfra.com/en/2.x/getting-started.html#
#File:      docker_pyinfra_install.sh
#Date:      2022DEC11
#Author:    William Blair
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11, MX 21
#Arch:      amd_64
#
#This script will create a pyinfra server
#- TODO:
################################################################################
IMAGE_SOURCE="debian:11-slim"
IMAGE_NAME="pyinfra:2.5.3"
COMPOSE_FILE="docker-compose.yaml"
docker pull "$IMAGE_SOURCE"
#---------------------------------------------------------------------------------

#generate DOCKERFILE
cat > Dockerfile << EOF
FROM $IMAGE_SOURCE

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet --quiet --yes update
RUN apt-get --quiet --quiet --yes --no-install-recommends \
    --option "DPkg::Options::=--force-confold" \
    --option "DPkg::Options::=--force-confdef" \
    install apt-utils ca-certificates curl liblinux-usermod-perl python3-pip passwd ssh python3-venv
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

RUN useradd -m -s /bin/bash "pyinfra" \
    && echo ""pyinfra":"pyinfra"" | chpasswd \
    && /usr/sbin/usermod -aG sudo "pyinfra"

ENV PATH="$PATH:/home/pyinfra/.local/bin:/home/pyinfra/.pyinfra"

USER pyinfra
RUN mkdir -p /home/pyinfra/.local/bin
RUN mkdir -p /home/pyinfra/pyinfra
WORKDIR /home/pyinfra/.local/bin

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py --user
RUN python3 -m pip install --user argcomplete
RUN python3 -m pip install --user pipx
RUN python3 -m pipx ensurepath
RUN pipx install pyinfra

RUN ./activate-global-python-argcomplete --user

WORKDIR /home/pyinfra/pyinfra

#use this to run container forever if you need to troubleshoot
#this should be just fine for pyinfra too
CMD exec /bin/sh -c "trap : TERM INT; (while true; do sleep 1000; done) & wait"
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
    pyinfra:
        #image: localhost:5000/$IMAGE_NAME
        image: $IMAGE_NAME
        restart: unless-stopped
        networks:
            <network_name>:
                ipv4_address: <ip_address>
        ports:
            - "22:22"

        volumes:
            - ./pyinfra:/home/pyinfra/pyinfra
            - ./.ssh:/home/ansible/.ssh:rw            
            
        stdin_open: true # docker run -i
        tty: true        # docker run -t
networks:
  <network_name>:
    external: true
EOF
#---------------------------------------------------------------------------------
