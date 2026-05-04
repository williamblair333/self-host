#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#https://pythonspeed.com/articles/system-packages-docker
#Run example: ./install_packages.sh
#Date:        2022MAY23
#Author:      Itamar Turner-Trauring
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#This script is intended to do the following:
#Reduce Docker image size by deleting files after installing packages
#Installs packages from file packages.txt
#################################################################################

# Tell apt-get we're never going to be able to give manual feedback:
export DEBIAN_FRONTEND=noninteractive

# Update the package listing, so we know what package exist:
apt-get update

# Install security updates:
apt-get --yes upgrade

#Put all packages you want to install in packages.txt in root directory
PKG_LIST=packages.txt

# Install packages from $PKG_LIST sans unnecessary recommended packages:
while IFS= read -r package; do
    echo "$package"
    apt-get --yes install --no-install-recommends "$package"
done < "$PKG_LIST"

# Delete cached files we don't need anymore
apt-get clean
# Delete index files we don't need anymore:
rm -rf /var/lib/apt/lists/*
#################################################################################
