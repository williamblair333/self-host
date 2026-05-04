# Use the Debian Buster Slim image as the base image
FROM debian:bookworm-slim

# Install Apache and OpenSSH Server
RUN apt-get update && \
    apt-get install -y apache2 openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Set up SSH
RUN mkdir /var/run/sshd

COPY ssl-cert-manager /root/.ssh/
COPY ssl-cert-manager.* /root/.ssh/

# add pub key && fix permissions in /root
RUN echo 'root:root' | chpasswd && \
    echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/kJf/eBSYSPmlvcRsCjfLi5GQ6tj8JX1Pfslj8ODNRgBgZykHVzK35V4yaF6oXnbLEpO4BEpJgr/943ty242R8Kalr+ybVGfSOzw679XX2qN4rFCciDA2m+PNxT1Otl3elbHTwBdk2nIQywN06nsDJVA8ut6tKTWYU7xsg9ZOIIJudn9+xzgwAbtO++LHCS/w9c+a1t8Q5bWVZNMSl2fDSnGjrgtJBiwX8km2dlnk8KuuAU3pdfcyGZwajPZDnBR9bmihdkwx5d4bZb2RD6M6bbAs7W+xUf7/JvUBq/bhNyCRM7ov3RTb05dXpWfY119dR+/DiPJ9EHFXFwniAb48l7tEMfLiP5MjCHj2qub5azwx+QrrusM1ySX/aWVomcslRCbIBO5fi7/CxlU8WX4qckjSPJNwvO4BReo2CCHwyWmX8un1lTL2VVKFtCXDwRi1q4mHKVNzqvMTJZm4HjDAbqlJnOxK6EzppVdSs7qJtATNXsfNrcjDGVs7c2zaFHxp1sdJOYvTHwbu2dvtpbMAHXk9QvIAV8LPF2owNrEouxNJPIzxXRWaH7JIo4PRqqEvI5heMGTc+PKJNd8ZBhQAe7jbZw6S6GjQpOj04bwGCRblDFq/3spbBd5SyHcNE3M3sQMD0n1vSIiTWZSphJsfXQ66KWpWQnyMeUJqw3XGHw== bill@dma370' > /root/.ssh/authorized_keys && \
    chmod -R 0700 /root/.ssh && \
    chmod 0600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config 

# Expose the necessary ports
EXPOSE 22 80 443

# Run Apache in the foreground alongside SSH server
CMD service ssh start && /usr/sbin/apache2ctl -D FOREGROUND
