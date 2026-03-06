#!/bin/bash
set -e

SFTP_USER=${SFTP_USER:-lab}
SFTP_PASS=${SFTP_PASS:-lab}

# Generate host keys if not already present
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
[ -f /etc/ssh/ssh_host_rsa_key ]     || ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''

# Chroot must be owned by root
mkdir -p /chroot/files
chown root:root /chroot
chmod 755 /chroot

# Create user, bind the shared volume subdir
useradd -M -d /chroot -s /bin/false -u 1000 "$SFTP_USER" 2>/dev/null || true
echo "$SFTP_USER:$SFTP_PASS" | chpasswd

# Fix ownership of files dir so user can write
chown "$SFTP_USER":root /chroot/files
chmod 755 /chroot/files

exec /usr/sbin/sshd -D -e
