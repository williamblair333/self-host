# Docker SSL Cert Manager

Docker SSL Cert Manager is a Dockerized solution for managing SSL/TLS certificates for your local domains using a private Certificate Authority (CA). This project encapsulates the process of certificate generation, distribution to a web server, executing arbitrary commands on the remote server, and restarting the web server, all within a Docker container.

## Features

- Setup a private Certificate Authority (CA) to issue certificates for local domains.
- Automated certificate generation for specified domains.
- Secure transfer of certificates to a remote web server.
- Execution of arbitrary commands on the remote server.
- Automated web server restart to apply the new certificates.

## Prerequisites

- Docker
- Docker Compose

## Directory Structure

docker-ssl-cert-manager/  
├── Dockerfile: Defines the Docker container including the necessary dependencies.  
├── docker-compose.yml: Docker Compose configuration file.  
├── .app/file_transfer_util.py: Utility for transferring files to remote servers.  
├── .app/setup-cert.py: Script to generate SSL certificates.  
├── .app/ssh_util.py: Utility for creating SSH connections and executing commands on remote servers.  
├── .app/web_server_util.py: Script to restart the web server on a remote server.  

## Getting Started

1. **Clone this repository to your local machine**:
    ```bash
    git clone https://github.com/williamblair333/docker-ssl-cert-manager.git
    cd docker-ssl-cert-manager
    ```
2. **Generate a certificate for a domain**:

    ```bash
    docker-compose run --rm ca python setup-cert.py mydomain
    ```

3. **Transfer the generated certificate and key to a remote server. apache2 is used in this example**:

    ```bash
    docker-compose run --rm ca python file_transfer_util.py --key /root/.ssh/id_rsa --source /app/certs/mydomain.crt --target root@web-server-ip:/etc/ssl/certs/mydomain.crt
    docker-compose run --rm ca python file_transfer_util.py --key /root/.ssh/id_rsa --source /app/certs/mydomain.key --target root@web-server-ip:/etc/ssl/private/mydomain.key 
        
    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command "uptime"
    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command "chmod 0644 /etc/ssl/certs/mydomain.crt"
    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command "chmod 0640 /etc/ssl/private/mydomain.key"
    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command  'cp /etc/apache2/sites-available/default-ssl.conf.bak /etc/apache2/sites-available/mydomain.conf'

    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command "bash -c \"echo -e '<VirtualHost *:443>\\n    ServerAdmin webmaster@mydomain\\n    ServerName mydomain\\n    DocumentRoot /var/www/html\\n    ErrorLog ${APACHE_LOG_DIR}/error.log\\n    CustomLog ${APACHE_LOG_DIR}/access.log combined\\n    # Enable SSL\\n    SSLEngine on\\n    SSLCertificateFile /etc/ssl/certs/mydomain.crt\\n    SSLCertificateKeyFile /etc/ssl/private/mydomain.key\\n</VirtualHost>' > /etc/apache2/sites-available/mydomain.conf\" && a2ensite mydomain.conf && apachectl configtest"
    docker-compose run --rm ca python ssh_util.py --key /root/.ssh/id_rsa --server web-server-ip --command "a2enmod ssl"
    ```
4. **Restart the web server on the remote server to apply the new certificate**:

    ```bash
    docker-compose restart
    ```

    Replace `apache2` with `nginx` or other web server software if necessary.

## Notes, Security

- Ensure that your SSH keys and other sensitive data are securely handled and not exposed to unauthorized individuals or systems. 
- This project is intended for local development and testing purposes and may need additional security hardening for production use.

## Notes, General

- The `docker-compose run` commands allow you to execute the scripts within the Docker container while interacting with remote servers.
- Ensure the remote server accepts SSH connections and the specified user has the necessary permissions to write to the `/path/to/certs/` directory and restart the web server.

## Test apache2 image and container
A docker apache2 image using Debian Bookworm is attached for convenience to illustrate / test adding the certs.
