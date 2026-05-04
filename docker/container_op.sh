#!/bin/bash
#################################################################################
# File:        container_op.sh
# Date:        2022FEB14
# Author:      William Blair
# Contact:     williamblair333@gmail.com
# Tested on:   Debian 11, Ubuntu 20+
#
# Description:
# This script loops through all Docker containers and applies operations such as
# start, stop, or remove. It enhances troubleshooting efficiency by allowing
# quick operations on all containers.
#
# Usage:
# ./container_op.sh [start|stop|rm]
#################################################################################

# Function to display help
show_help() {
    echo "Usage: $0 [start|stop|rm]"
    echo "Operations:"
    echo "  start    Start all containers"
    echo "  stop     Stop all containers"
    echo "  rm       Remove all containers"
}

# Check for valid number of arguments
if [ $# -ne 1 ]; then
    echo "Error: Incorrect number of arguments."
    show_help
    exit 1
fi

# Validate operation argument
case $1 in
    start|stop|rm)
        operation=$1
        ;;
    *)
        echo "Error: Invalid operation."
        show_help
        exit 1
        ;;
esac

# Get a list of all container IDs
container_ids=$(sudo docker container ls --all --quiet)

# Apply operation to each container
for container_id in $container_ids; do
    echo "Applying '$operation' to container $container_id"
    sudo docker container "$operation" "$container_id"
done
