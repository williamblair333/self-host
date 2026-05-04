# A postfix mail relay using Debian Bookworm Slim in Docker

# Mail Relay Docker Container

This repository contains the necessary files to set up a Postfix mail relay using Docker. The mail relay listens on port `25` and relays mails securely using STARTTLS.

## Prerequisites

- Docker installed on your machine.
- docker-compose installed on your machine.

## Setup

### 1. Clone the Repository

git clone https://github.com/williamblair333/docker-postfix-relay-debian.git
cd docker-postfix-relay-debian

### 2. Configuration

#### Postfix Configuration

Before you start the relay, ensure you adjust the `main.cf` configuration file according to your requirements.

#### Hosts Configuration

The provided `hosts` file is mapped to the container to provide hostname resolutions. Ensure the IP addresses and hostnames match your local network setup. If you have additional domains or subdomains you want the relay to recognize or if you change the configuration of your local network, update this file accordingly.

### 3. Build & Run

Using `docker-compose`:

docker-compose up --build -d

This command will build the Docker image and run it in detached mode.

### 4. Testing

After you have the relay running, you can test it by sending an email via this relay to ensure it works as expected.

## Notes

- Remember to ensure that your firewall settings allow for traffic on port `25` if you're deploying this in a networked or cloud environment.
- The relay is configured to trust the `192.168.1.0/24` subnet for mail relay. Adjust this in `main.cf` if your requirements are different.
- The `hosts` file is crucial for DNS resolution within the container. Keep it updated based on your network's configuration and any changes you make.
- Always test in a controlled, non-production environment first before deploying to production.

Made mostly with OpenAI's chatgpt4
