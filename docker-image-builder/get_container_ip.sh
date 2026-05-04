#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#put tips, tricks and other stuff here. Maybe make a lib of sorts one day.
#################################################################################

#assign container ip address to variable
function get_container_ip () {
    container_ip=$(docker inspect "$1" -f "{{json .NetworkSettings.Networks }}" \
      | awk -v FS=: '{print $9}' \
      | cut -f1 -d\,)
      
    container_ip=$(echo "${container_ip//\"}")
}

get_container_ip $1
echo "$container_ip"

