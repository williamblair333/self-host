#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#
#Run example: ./install_users.sh
#Date:        2022MAY23
#Author:      William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#This script is intended to do the following:
#Add user accounts to a Dockerfile for Docker build and add to sudo group
#
#################################################################################

USR_LIST=users.csv

# Install packages from $USR_LIST sans unnecessary recommended packages:
while IFS=, read -r user password; do
    useradd -m -s /bin/bash "$user"
    #echo "$password" | passwd --stdin "$user"
    echo ""$user":"$password"" | chpasswd
    usermod -aG sudo "$user"
done < "$USR_LIST"
#################################################################################
