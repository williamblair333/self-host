#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
################################################################################
#READ THE COMMENTS BEFORE RUNNING
#File:      install_jenkins.sh
#Date:      2022JUN23
#Author:    William Blair
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11
#Arch:      amd_64
#
#This script will create a Jenkins container with desired plugins already installed
#and migrate jobs and history from JENKINS_HOME (compressed into jenkins.zip)
#to attached docker volumes that Jenkins will use
#- TODO:
################################################################################

PATH=/usr/local/bin:$PATH

#create docker volume directory/subdirectories
DOCKER_VOLUME_ROOT="opt/docker/jenkins"
DOCKER_VOLUMES="{jenkins_home,docker-certs,docker.sock}"
mkdir -p /"$DOCKER_VOLUME_ROOT" && \
    mkdir -p /"$DOCKER_VOLUME_ROOT"/"$DOCKER_VOLUMES"

#populate plugins.txt
./jenkins-get-plugin-list.sh
