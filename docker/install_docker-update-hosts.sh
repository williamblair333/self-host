#!/usr/bin/env bash
#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug
#################################################################################
#https://stackoverflow.com/questions/37242217/access-docker-container-from-host-using-containers-name/45071126#45071126
#File:      install-docker-update-hosts.sh
#Date:      2022JUL06
#Author:    fnkr@stackoverflow
#Contact:   williamblair333@gmail.com
#Distro:    Debian 11
#Arch:      amd_64
#
#The purpose of this script is to: update docker hostnames and ip addresses in
#/etc/hosts
#The script will:
#-create docker-update-hosts.sh
#-create systemd /etc/systemd/system/docker-update-hosts.service and activate it
#=REQUIREMENTS: package jq
#- TODO:
################################################################################
FILE_NAME='docker-update-hosts'
BIN_DIR='usr/local/bin'
SVC_DIR='etc/systemd/system'
hosts_file='/etc/hosts'
begin_block='# BEGIN DOCKER CONTAINERS'
end_block='# END DOCKER CONTAINERS'
#---------------------------------------------------------------------------------

cat << EOF > /"$BIN_DIR"/"$FILE_NAME".sh
#!/usr/bin/env bash

if ! grep -Fxq "$begin_block" "$hosts_file"; then
    echo -e "\n${begin_block}\n${end_block}\n" >> "$hosts_file"
fi

(echo "| container start |" && docker events) | \


while read event; do
    if [[ "$event" == *" container start "* ]] \
        || [[ "$event" == *" network disconnect "* ]]; then
            hosts_file_tmp="$(mktemp)"
            docker container ls -q \
            | xargs -r docker container inspect \
            | jq -r '.[]|"\(.NetworkSettings.Networks[].IPAddress|select(length > 0) // "# no ip address:") \
            (.Name|sub("^/"; "")|sub("_1$"; ""))"' \
            | sed -ne "/^${begin_block}$/ {p; r /dev/stdin" -e ":a; n; /^${end_block}$/ \
            {p; b}; ba}; p" "$hosts_file" \
            > "$hosts_file_tmp"
            
            chmod 644 "$hosts_file_tmp"
            mv "$hosts_file_tmp" "$hosts_file"
    fi
done
EOF
#---------------------------------------------------------------------------------

cat << EOF > /"$SVC_DIR"/"$FILE_NAME".service
[Unit]
Description=Update Docker containers in /etc/hosts
Requires=docker.service
After=docker.service
PartOf=docker.service

[Service]
ExecStart=/"$BIN_DIR"/"$FILE_NAME".sh

[Install]
WantedBy=docker.service
EOF

chmod +x /"$BIN_DIR"/"$FILE_NAME".sh
#---------------------------------------------------------------------------------

systemctl daemon-reload
systemctl enable "$FILE_NAME".service
systemctl start "$FILE_NAME".service
#---------------------------------------------------------------------------------
