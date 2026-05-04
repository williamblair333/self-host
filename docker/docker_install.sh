#!/usr/bin/env bash

#################################################################################
# Docker Installation Script
#
# Requirements:
#   detect_os.sh
# Purpose:
#   Automates the installation of Docker and its dependencies on Debian-based Linux systems.
#   This script dynamically adapts to different versions of Debian and Ubuntu, ensuring
#   the correct installation of Docker packages.
#
# Usage:
#   Command: ./docker_install.sh
#
# References:
#   Docker Installation Guide for Debian: https://docs.docker.com/engine/install/debian/
#   Post-installation steps for Linux: https://docs.docker.com/engine/install/linux-postinstall/
#
# Maintenance Information:
#   Date Created: 2022MAY14
#   Last Updated: [Date of Last Update]
#   Author: Docker Team
#   Contact: williamblair333@gmail.com
#   Tested on: Debian and Ubuntu (various versions)
#
# The script does the following:
#   - Removes any older versions of Docker (e.g., docker, docker.io)
#   - Sets up the official Docker repository and installs Docker Engine, Docker CLI,
#     and containerd.
#   - Adds the user who initiated the script the docker group
#################################################################################

#set -x
#set -e
#trap read debug
set -eu -o pipefail


source ./detect_os.sh

# Function to check and uninstall Docker, Docker Compose, and Buildx

uninstall_docker_components() {
    # Check if Docker is installed
    if [ -x "$(command -v docker)" ]; then
        echo "Docker is installed. Uninstalling..."
        sudo apt-get remove --yes docker-ce docker-ce-cli containerd.io
    else
        echo "Docker is not installed."
    fi

    # Check if Docker Compose is installed
    if [ -x "$(command -v docker-compose)" ]; then
        echo "Docker Compose is installed. Uninstalling..."
        sudo apt-get remove --yes docker-compose
    else
        echo "Docker Compose is not installed."
    fi

    # Check if Docker Buildx is installed
    if docker buildx ls &> /dev/null; then
        echo "Docker Buildx is installed. Uninstalling..."
        sudo rm -f /usr/libexec/docker/cli-plugins/docker-buildx
    else
        echo "Docker Buildx is not installed."
    fi
}

# Function to install Docker
install_docker() {
    OS=$(detect_os)
    echo "Installing Docker on $OS..."

    # Update package list
    sudo apt-get update || { echo "Failed to update package list"; exit 1; }

    # Install required packages
    sudo apt-get install --yes ca-certificates curl gnupg lsb-release || { echo "Failed to install required packages"; exit 1; }

    # Backup existing Docker GPG key if present
    if [ -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        echo "Backing up existing Docker GPG key..."
        sudo mv /usr/share/keyrings/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.gpg.backup
    fi

    # Add Docker’s official GPG key
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || { echo "Failed to add Docker's GPG key"; exit 1; }

    # Set up the stable repository for Ubuntu or Debian
    echo "Setting up Docker repository for $OS..."
    REPO_URL="https://download.docker.com/linux/$OS"

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $REPO_URL $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "Failed to set up Docker repository"; exit 1; }

    # Install Docker Engine, CLI, and Docker Compose plugin
    sudo apt-get update || { echo "Failed to update package list after adding Docker repository"; exit 1; }
    sudo apt-get install --yes docker-ce docker-ce-cli containerd.io docker-compose-plugin || { echo "Failed to install Docker Engine or Compose plugin"; exit 1; }

    echo "Adding the user who launched the script to the Docker group..."
    if [ "$SUDO_USER" ]; then
        sudo usermod -aG docker $SUDO_USER
    else
        sudo usermod -aG docker $(whoami)
    fi
    echo "Docker installation completed successfully on $OS."
}

#Check for and uninstall existing Docker components.
uninstall_docker_components

# Install Docker
install_docker

# End of script
