#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#
#Run example: ./install_net_snmp.sh
#Date:        2022MAY23
#Author:      William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#This script is intended to do the following:
#Setup net-snmp, pull mibs from a git repo and install them
#
#################################################################################

#user=remote
#user_snmp_home=home/"$user"/.snmp

# set non-free in /etc/apt/sources.list
sudo apt-get update
sudo apt-get --yes install snmp snmp-mibs-downloader tkmib smitools
 
sudo sed -i 's/mibs :/#mibs :/g' /etc/snmp/snmp.conf
 
#switch to your favorite user account

mkdir -p "$HOME"/.snmp/mibs && cd "$HOME"/.snmp/mibs
echo "mibdirs +""$HOME"/.snmp"/Source" >> "$HOME"/.snmp/snmp.conf
 
#bli-git ip is: 10.120.25.72
git init && git pull http://10.120.25.72/cgit.cgi/alpha/mibs.git && cd Source
sudo download-mibs
