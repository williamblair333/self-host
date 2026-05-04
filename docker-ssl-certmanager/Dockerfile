# Use an official Python runtime as a base image
FROM python:3.11.5-slim-bookworm

# Install OpenSSL and SSH client
RUN apt-get --quiet --quiet --yes update 1>/dev/null && \
    apt-get --quiet --quiet --yes --no-install-recommends \
        --option "DPkg::Options::=--force-confold" \
        --option "DPkg::Options::=--force-confdef" \
        install openssl openssh-client 1>/dev/null && \
    rm --recursive --force /var/lib/apt/lists/* 1>/dev/null      

# Install paramiko
RUN pip install paramiko

# Create a directory for the .py file and certs
RUN mkdir --parents /app/certs
    
COPY ./app/* /app/
COPY ssl-cert-manager /root/.ssh/
COPY ssl-cert-manager.* /root/.ssh/

# fix permissions in /root
RUN touch /root/.ssh/authorized_keys && \
    chmod -R 0700 /root/.ssh && \
    chmod 0600 /root/.ssh/authorized_keys

# Set the working directory in the container to /app
WORKDIR /app

# Command to keep the container running indefinitely troubleshooting
#CMD ["tail", "-f", "/dev/null"]
