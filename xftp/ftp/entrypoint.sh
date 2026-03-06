#!/bin/bash
set -e

FTP_USER=${FTP_USER:-lab}
FTP_PASS=${FTP_PASS:-lab}
PASV_ADDRESS=${PASV_ADDRESS:-127.0.0.1}
PASV_MIN=${PASV_MIN:-21000}
PASV_MAX=${PASV_MAX:-21010}

# pam_shells.so requires the user's shell to be listed in /etc/shells
grep -qxF '/bin/false' /etc/shells || echo '/bin/false' >> /etc/shells

useradd -m -d /ftp -s /bin/false "$FTP_USER" 2>/dev/null || true
echo "$FTP_USER:$FTP_PASS" | chpasswd

cat >> /etc/vsftpd.conf <<EOF
pasv_address=${PASV_ADDRESS}
pasv_min_port=${PASV_MIN}
pasv_max_port=${PASV_MAX}
local_root=/ftp
EOF

mkdir -p /var/run/vsftpd/empty
exec /usr/sbin/vsftpd /etc/vsftpd.conf
