# Docker Gui For snmpb

## Features

- Deploy snmpb browser in a dockerized GUI.
- Running on Debian Buster Slim i386 with its dependencies (dpkg -I <package_name>.deb to see them).

- [Dogma](https://github.com/williamblair333/dogma) may be useful for running GUIs living in Docker containers.

## Prerequisites

- Docker
- Docker Compose
- X11 Server for GUI

## Directory Structure

snmpb/  
├── Dockerfile: Defines the Docker container including the necessary dependencies.  
├── docker-compose.yml: Docker Compose configuration file.  
├── snmpb_0.8_i386.deb:  The snmpb package.  
└── logs/: It's supposed to store logs here.  
└── root/: Allows for storing all changes in order to persist upon container destruction and construction  
└── tmp/: It might be useful to keep.  

## Getting Started

1. **Clone the repository**:
    ```bash
    git clone https://github.com/williamblair333/docker-gui-snmpb.git
    cd docker-gui-snmpbrowser
    ```

2. **Build and start the Docker container**:
    ```bash
    docker-compose up --build
    ```

3. **Run snmpb**:
    ```bash
    sudo xhost +  
    docker exec -it <container_name> snmpb  
    sudo xhost -  
    ```

## TODO

- Need to test if we need more volumes when adding mibs.  If so, where?  Run docker diff <container_id> to find out!
