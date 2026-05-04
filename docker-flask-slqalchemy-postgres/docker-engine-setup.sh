#!/bin/bash
#################################################################################
#
#Run example: N/A
#File:        docker-engine-setup.sh
#Date:        2022FEB11
#Author:      William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#To test:     Ubuntu 21+
#
#This script is intended to do the following:
#
#- install Docker engine onto a server running Debian 11 Bullseye
#
#################################################################################

#Get rid of an Docker Debian distro related packages if they exist
sudo apt-get remove docker docker-engine docker.io containerd runc

#Install some necessary packages 
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

#Set up gpg key
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    sudo gpg --dearmor \
    -o /usr/share/keyrings/docker-archive-keyring.gpg

#Set up sources so we can grab Docker latest
echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#Now install Docker
sudo apt-get update && sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io

docker version
