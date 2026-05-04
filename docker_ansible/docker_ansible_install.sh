#!/usr/bin/env bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug

################################################################################
#READ THE COMMENTS BEFORE RUNNING
#-https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
#File:      docker_ansible_install.sh
#Date:      2022NOV30
#Author:    William Blair
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11, MX 21
#Arch:      amd_64
#
#This script will create an ansible server
#- TODO:
################################################################################
IMAGE_SOURCE="debian:11-slim"
IMAGE_NAME="ansible:2.13"
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
    install apt-utils ca-certificates curl liblinux-usermod-perl python3-pip passwd ssh
RUN apt-get --quiet --quiet --yes autoremove
RUN apt-get --quiet --quiet --yes clean
RUN rm -rf /var/lib/apt/lists/* 1>/dev/null

RUN useradd -m -s /bin/bash "ansible" \
    && echo ""ansible":"ansible"" | chpasswd \
    && /usr/sbin/usermod -aG sudo "ansible"

RUN mkdir /etc/ansible
USER ansible

WORKDIR /home/ansible
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python3 get-pip.py --user
RUN python3 -m pip install --user ansible-core==2.13
RUN python3 -m pip install --user argcomplete

USER ansible
WORKDIR /home/ansible/.local/bin
RUN ./activate-global-python-argcomplete --user
RUN ./ansible --version

ENV PATH="$PATH:/home/ansible/.local/bin:/home/ansible/.ansible"

#CMD ["sh", "./ansible"]
#use this to run container forever if you need to troubleshoot
#this should be just fine for ansible too
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
    ansible:
        #image: localhost:5000/$IMAGE_NAME
        image: $IMAGE_NAME
        restart: unless-stopped
        networks:
            <network_name>:
                ipv4_address: <ip_address>
        ports:
            - "22:22"

        volumes:
            - ./ansible.cfg:/etc/ansible/ansible.cfg:rw
            - ./.ssh:/home/ansible/.ssh:rw            
            - ./hosts:/etc/ansible/hosts:rw
            - ./collections:/home/ansible/.ansible/collections:rw
            - ./playbooks:/home/ansible/.ansible/playbooks:rw
            - ./roles:/home/ansible/.ansible/roles:rw
            - ./tasks:/home/ansible/.ansible/tasks:rw
            
        stdin_open: true # docker run -i
        tty: true        # docker run -t
networks:
  <network_name>:
    external: true
EOF
#---------------------------------------------------------------------------------

#./ansible_alias_bashrc.sh
#---------------------------------------------------------------------------------
