#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
################################################################################
#https://stackoverflow.com/questions/9815273/how-to-get-a-list-of-installed-jenkins-plugins-with-name-and-version-pair
#File:      jenkins-get-plugin-list.sh
#Date:      2022JUN28
#Author:    Andrzej Rehmann
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11
#Arch:      amd_64
#
#This script will return a list of all installed Jenkins plugins in 
#shortName:version format #and pipe said list to a file (usually plugins.txt)
#- TODO: 
################################################################################

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jenkins_url="http://192.168.1.191:8080/pluginManager/api/json?depth=1"
plugin_list="plugin-name.txt"

echo "$__dir"/"$plugin_list"

[[ ! -f "$plugin_list" ]] && touch "$__dir"/"$plugin_list"
  #| jq -r '.plugins[] | "\(.shortName):\(.version)"' \
curl -s -u 'admin:!1qqaazz' "$jenkins_url" \
  | jq -r '.plugins[] | "\(.shortName)"' \
  | sort \
  | tee -a "$__dir"/"$plugin_list"
