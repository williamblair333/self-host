#!/usr/bin/env bash

# Function to determine OS type
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        echo $OS
    else
        echo "OS not detected. This script may not support your OS."
        exit 1
    fi
}
