#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#
#Run example: ./install_services.sh
#Date:        2022MAY23
#Author:      William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#This script is intended to do the following:
#Install services deemed necessary for container
#
#################################################################################

# Services will / may / maybe go in this file
SVC_LIST=services.csv

# Install packages from $USR_LIST sans unnecessary recommended packages:
while IFS=, read -r user service; do
    systemctl start "$service"
done < "$USR_LIST"
#################################################################################
