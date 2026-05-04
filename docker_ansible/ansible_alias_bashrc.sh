#!/bin/bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug

BASHRC=~/.bashrc
cat << EOF >> "$BASHRC"

#ansible alias commands begin
alias ansible='docker exec -it ansible_ansible_1 ./ansible'
alias ansible-config='docker exec -it ansible_ansible_1 ./ansible-config'
alias ansible-connection='docker exec -it ansible_ansible_1 ./ansible-connection'
alias ansible-console='docker exec -it ansible_ansible_1 ./ansible-console'
alias ansible-doc='docker exec -it ansible_ansible_1 ./ansible-doc'
alias ansible-galaxy='docker exec -it ansible_ansible_1 ./ansible-galaxy'
alias ansible-inventory='docker exec -it ansible_ansible_1 ./ansible-inventory'
alias ansible-playbook='docker exec -it ansible_ansible_1 ./ansible-playbook'
alias ansible-pull='docker exec -it ansible_ansible_1 ./ansible-pull'
alias ansible-test='docker exec -it ansible_ansible_1 ./ansible-test'
alias ansible-vault='docker exec -it ansible_ansible_1 ./ansible-vault'
#ansible alias commands end
EOF
