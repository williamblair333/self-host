#!/usr/bin/env bash

set -o errexit
set -o nounset
set -eu -o pipefail

#################################################################################
# File:        apt_packages.sh
# Date:        2022MAY23
# Author:      Itamar Turner-Trauring
# Contact:     williamblair333@gmail.com
# Tested on:   Debian 11
# Description:
# This script installs packages from a specified file and cleans up to reduce
# Docker image size. It's designed for use in Docker containers based on Debian.
# Usage:
# ./apt_packages.sh [path_to_package_list.txt]
#################################################################################

# Function to display help
show_help() {
    echo "Usage: $0 [path_to_package_list.txt]"
    echo "The file should contain a list of packages to install, one per line."
}

# Check if a file path is provided
if [ $# -ne 1 ]; then
    echo "Error: Please provide a path to the package list file."
    show_help
    exit 1
fi

# Assign the first argument as the package list file
PKG_LIST=$1

# Check if the package list file exists
if [ ! -f "$PKG_LIST" ]; then
    echo "Error: File '$PKG_LIST' not found."
    exit 1
fi

# Tell apt-get we're never going to be able to give manual feedback:
export DEBIAN_FRONTEND=noninteractive

# Update the package listing:
apt-get update

# Install security updates:
apt-get --yes upgrade

# Install packages from $PKG_LIST sans unnecessary recommended packages:
while IFS= read -r package; do
    echo "Installing $package"
    apt-get --yes install --no-install-recommends "$package"
done < "$PKG_LIST"

# Delete cached files and index files we don't need anymore:
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Packages from $PKG_LIST installed and cleanup completed."

