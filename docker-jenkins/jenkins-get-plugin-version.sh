#!/usr/bin/env bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#https://gist.github.com/mpailloncy/2c411446664cd8544bd2d46e62e225f2
#File:        ./jenkins-get-plugin-version.sh
#Date:        2022JUN28
#Author:      Michaël Pailloncy with input from William Blair
#Contact:     williamblair333@gmail.com
#Tested on:   Debian 11
#
#This script is intended to do the following:
#-Retrieve latest version of plugins from Jenkins server piped into a file
#    (plugin-name.txt) and pipe results into docker-jenkins-plugins.txt
#-Grab latest version of each plugin and pipe into plugins.txt
#See https://github.com/jenkinsci/plugin-installation-manager-tool for case uses
#TODO 
#################################################################################
#source jenkins-get-plugin-list.sh

function package_check() {
    PACKAGES=$1
    for package in $PACKAGES; do 
        CHECK_PACKAGE=$(sudo dpkg -l \
        | grep --max-count 1 "$package" \
        | awk '{print$ 2}')
            
        if [[ ! -z "$CHECK_PACKAGE" ]]; then 
            echo "$package" 'is already installed'; 
        else 
            sudo apt-get --yes install --no-install-recommends "$package"
        fi
    done
}
#################################################################################

function get_plugin_list() {
    __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    #echo "$__dir"/$2

    [[ ! -f $2 ]] && touch "$__dir"/$2
    #| jq -r '.plugins[] | "\(.shortName):\(.version)"' \
    curl -s -u $3 $1 \
    | jq -r '.plugins[] | "\(.shortName)"' \
    | sort \
    | tee -a "$__dir"/$2

}
#################################################################################

function plugin_list_check() {
    [[ ! -f $1 ]] && \
        echo "[ERROR] File listing target plugins not found : $1. \
        Please create it (one plugin id by line)." && exit 2
}
#################################################################################

function get_plugin_version () {
    echo "Fetching latest plugins version from update center ..."
    json=$(curl -sL $1)
    latestVersions=$(echo "${json}" \
        | jq --raw-output '.plugins[] | .name + ":" + .version')

    plugins=$(cat $2 | grep -vE '^(\s*$|#)')

    echo ""
    while read plugin; do
        
        result=$(echo "$latestVersions" | grep -E "^${plugin}:")
        if [[ "$?" == "0" ]]; then
            echo "${result}" >> $3
        else
            echo "[WARNING] Plugin ${plugin} not found "
        fi	

    done <<< "${plugins}"
}
#################################################################################

function main() {
    __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    package_check 'curl jq'
    
    jenkins_url="http://192.168.1.191:8080/pluginManager/api/json?depth=1"
    plugin_list="plugin-name.txt"
    jenkins_auth='admin:!1qqaazz'
    get_plugin_list "$jenkins_url" "$plugin_list" "$jenkins_auth"
    plugin_list_check "$plugin_list" "$plugin_list"
    
    url="https://updates.jenkins.io/current/update-center.actual.json"
    plugin_result="${__dir}/plugins.txt"
    [[ -f "$plugin_result" ]] && rm "$plugin_result"
    get_plugin_version "$url" "$plugin_list" "$plugin_result"
}
#################################################################################

main "$@"
#################################################################################
