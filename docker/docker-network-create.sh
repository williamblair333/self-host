#!/bin/bash

# Function to display help information
show_help() {
    echo "Usage: $0 [options] <network-name>"
    echo
    echo "Options:"
    echo "  -d, --driver       Specify the network driver (e.g., bridge, overlay)"
    echo "  -s, --subnet       Define the subnet in CIDR format (e.g., 192.168.3.0/27)"
    echo "  -i, --ip-range     Set the IP range in CIDR format (e.g., 192.168.3.0/28)"
    echo "  -g, --gateway      Set the network gateway (e.g., 192.168.3.1)"
    echo "  -h, --help         Display this help and exit"
    echo
    echo "Example:"
    echo "  $0 --driver bridge --subnet 192.168.3.0/27 --ip-range 192.168.3.0/28 --gateway 192.168.3.1 my_network"
}

# Default values
driver=""
subnet=""
ip_range=""
gateway=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--driver)
            driver=$2
            shift 2
            ;;
        -s|--subnet)
            subnet=$2
            shift 2
            ;;
        -i|--ip-range)
            ip_range=$2
            shift 2
            ;;
        -g|--gateway)
            gateway=$2
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            network_name=$1
            shift
            ;;
    esac
done

# Check for mandatory arguments
if [ -z "$driver" ] || [ -z "$subnet" ] || [ -z "$ip_range" ] || [ -z "$gateway" ] || [ -z "$network_name" ]; then
    echo "Error: Missing required arguments."
    show_help
    exit 1
fi

# Execute the Docker network create command
docker network create --driver="$driver" --subnet="$subnet" --ip-range="$ip_range" --gateway="$gateway" "$network_name"
