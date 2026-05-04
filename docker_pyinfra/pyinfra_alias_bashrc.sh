#!/bin/bash

#set -o errexit
#set -o nounset
#set -eu -o pipefail
#set -x
#trap read debug

BASHRC=~/.bashrc
cat << EOF >> "$BASHRC"

#pyinfra alias commands begin
alias pyinfra='docker exec -it pyinfra_pyinfra_1 pyinfra'
#pyinfra alias commands end
EOF
