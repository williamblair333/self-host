# 📦 xftp — Lab File Server Stack

> **Multi-protocol file server for network lab environments.**
> Single shared directory accessible via TFTP, SFTP, FTP, and HTTP.
> Designed for Cisco IOS management, config backups, and general lab use.

---

| Platform | Docker | TFTP | SFTP | FTP | HTTP | Base | License |
|----------|--------|------|------|-----|------|------|---------|
| MX Linux 25 / Debian Trixie | Compose v2 | UDP/69 | TCP/2222 | TCP/21 | TCP/8888 | debian:bookworm-slim | MIT |

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Directory Structure](#-directory-structure)
- [Services](#-services)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [Authentication](#-authentication)
- [Testing Each Service](#-testing-each-service)
- [Firewall](#-firewall)
- [Operations Reference](#-operations-reference)
- [Cisco IOS Usage](#-cisco-ios-usage)
- [Troubleshooting](#-troubleshooting)
- [Security Notes](#-security-notes)
- [File Reference](#-file-reference)

---

## 🔍 Overview

`xftp` is a containerized, multi-protocol file server built for network lab environments. All four services share a single bind-mounted directory on the host — a file uploaded via SFTP is immediately available over TFTP, FTP, or the web UI without any sync or copy step.

### Why each protocol

| Protocol | Port | Use Case |
|----------|------|----------|
| **TFTP** | UDP/69 | Cisco IOS firmware uploads, config backup/restore |
| **SFTP** | TCP/2222 | Secure file transfer from workstations |
| **FTP** | TCP/21 | Legacy device compatibility, passive mode support |
| **HTTP** | TCP/8888 | Web UI for browsing, uploading, downloading via browser |

### Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Base image | `debian:bookworm-slim` | Consistent, predictable, no Alpine surprises |
| TFTP networking | `network_mode: host` | Docker NAT breaks UDP/69 with Cisco IOS reliably |
| SFTP image | Custom build | `atmoz/sftp` has known hang bug with modern OpenSSH clients |
| FTP server | `vsftpd` | Stable, well-documented, Debian-native |
| HTTP UI | `filebrowser/filebrowser` | Scratch-based Go binary — no debian variant, scratch is correct |
| Shared storage | Bind mount `./files` | Direct host access, no volume driver overhead |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Host: 10.33.1.38                 │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌─────┐  ┌────────┐  │
│  │   TFTP   │  │   SFTP   │  │ FTP │  │  HTTP  │  │
│  │  :69/udp │  │  :2222   │  │ :21 │  │  :8888 │  │
│  └────┬─────┘  └────┬─────┘  └──┬──┘  └───┬────┘  │
│       │             │           │          │        │
│       └─────────────┴───────────┴──────────┘        │
│                          │                          │
│              ┌───────────▼──────────┐               │
│              │   ./files (host)     │               │
│              │   /opt/docker/xftp/  │               │
│              │   files/             │               │
│              └──────────────────────┘               │
└─────────────────────────────────────────────────────┘
```

```
Container mounts:
  fileserver-tftp  →  /files
  fileserver-sftp  →  /chroot/files
  fileserver-ftp   →  /ftp
  fileserver-http  →  /srv
```

> All four paths are bind-mounted to the same host directory.

---

## 📁 Directory Structure

```
/opt/docker/xftp/
├── docker-compose.yml          # Main stack definition
├── .env                        # Active config (do not commit)
├── .env.example                # Template — copy to .env
│
├── files/                      # ← SHARED FILE ROOT (all services)
│   └── ...your files here...
│
├── tftp/
│   └── Dockerfile              # debian:bookworm-slim + tftpd-hpa
│
├── sftp/
│   ├── Dockerfile              # debian:bookworm-slim + openssh-server
│   ├── sshd_config             # Hardened sshd config with chroot
│   └── entrypoint.sh          # User creation + host key generation
│
└── ftp/
    ├── Dockerfile              # debian:bookworm-slim + vsftpd
    ├── vsftpd.conf             # Base vsftpd configuration
    └── entrypoint.sh          # User creation + dynamic config injection
```

---

## 🐳 Services

### TFTP — `fileserver-tftp`

<details>
<summary><strong>Details</strong></summary>

| Property | Value |
|----------|-------|
| Image | Custom `debian:bookworm-slim` |
| Package | `tftpd-hpa` |
| Port | `UDP/69` (host network mode) |
| Auth | None — TFTP has no authentication by design |
| Upload | Enabled (`--create` flag) |
| Chroot | `/files` inside container |
| Networking | `network_mode: host` |

**Why `host` networking for TFTP:**
Docker's NAT layer does not reliably forward UDP traffic in the way TFTP requires.
Cisco IOS in particular uses the source port of the initial request for data transfer,
which breaks with NAT. `network_mode: host` bypasses this entirely.

**`tftp/Dockerfile`:**
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    tftpd-hpa \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 69/udp
ENTRYPOINT ["in.tftpd", "-L", "--secure", "--create", "/files"]
```

</details>

---

### SFTP — `fileserver-sftp`

<details>
<summary><strong>Details</strong></summary>

| Property | Value |
|----------|-------|
| Image | Custom `debian:bookworm-slim` |
| Package | `openssh-server` |
| Port | `TCP/2222` |
| Auth | Username + password via env vars |
| Chroot | `/chroot` — root-owned, required by OpenSSH |
| Files dir | `/chroot/files` — writable by user |
| Host keys | Persisted in named Docker volume `sftp-hostkeys` |

**Why custom build instead of `atmoz/sftp`:**
`atmoz/sftp` has a documented hang bug with modern OpenSSH clients where the session
stalls indefinitely after `subsystem request accepted`. The project is effectively
unmaintained. Building from `openssh-server` on bookworm-slim avoids this entirely.

**`sftp/sshd_config`:**
```
Port 22
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
Subsystem sftp internal-sftp
Match User lab
    ChrootDirectory /chroot
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

> ⚠️ `ChrootDirectory` must be owned by `root:root` with permissions `755`.
> This is an OpenSSH hard requirement — any other ownership silently breaks login.

</details>

---

### FTP — `fileserver-ftp`

<details>
<summary><strong>Details</strong></summary>

| Property | Value |
|----------|-------|
| Image | Custom `debian:bookworm-slim` |
| Package | `vsftpd` |
| Port | `TCP/21` (control) + `TCP/21000–21010` (passive data) |
| Auth | Username + password via env vars |
| Mode | Passive (PASV) — required for NAT/firewall traversal |
| Chroot | `/ftp` — user jailed to this directory |

**Passive mode explained:**

```
Client ──── PORT 21 ────→ Server    (control connection, client initiates)
Client ←─── PORT 21xxx ── Server    (data connection, server initiates in active)
Client ──── PORT 21xxx → Server     (data connection, client initiates in passive)
```

Passive mode is required when the client is behind NAT (almost always in a lab).
The `PASV_ADDRESS` must be the IP your FTP client connects to — not `0.0.0.0`.

**PAM note:** `pam_shells.so` in Debian's vsftpd PAM config rejects users whose shell
(`/bin/false`) is not listed in `/etc/shells`. The entrypoint adds `/bin/false` to
`/etc/shells` at startup to resolve this.

</details>

---

### HTTP — `fileserver-http`

<details>
<summary><strong>Details</strong></summary>

| Property | Value |
|----------|-------|
| Image | `filebrowser/filebrowser:latest` |
| Port | `TCP/8888` → container `80` |
| Auth | Toggleable via `HTTP_AUTH` env var |
| Default creds | `admin` / `admin` |
| Persistence | Settings/users in named volume `filebrowser-db` |

**Why not debian-based:** filebrowser is a statically compiled Go binary distributed
as a scratch image. There is no debian variant and none is needed — scratch is the
correct base for this type of binary.

**Change admin password:**
```bash
docker exec -it fileserver-http filebrowser users update admin --password yournewpass
```

</details>

---

## ✅ Prerequisites

```bash
# Verify docker and compose are available
docker --version
docker compose version

# Install tftp client for testing
sudo apt install -y tftp-hpa ftp sshpass
```

---

## 🚀 Quick Start

```bash
clear
cd /opt/docker/xftp
cp .env.example .env
vim .env                    # Set PASV_ADDRESS to your LAN IP at minimum
mkdir -p files
chmod 777 files             # tftpd runs as nobody — needs world-writable
docker compose build --no-cache
docker compose up -d
docker compose ps           # Verify all four are Up
```

---

## ⚙️ Configuration

### `.env.example`

```bash
# ── Shared storage ────────────────────────────────────────────────
FILES_DIR=./files

# ── SFTP ──────────────────────────────────────────────────────────
SFTP_USER=lab
SFTP_PASS=lab

# ── FTP ───────────────────────────────────────────────────────────
FTP_USER=lab
FTP_PASS=lab

# Passive mode — PASV_ADDRESS must match the IP clients connect to
PASV_ADDRESS=10.33.1.38
PASV_MIN=21000
PASV_MAX=21010

# ── HTTP filebrowser ──────────────────────────────────────────────
# true  = no login required (open access)
# false = login required (use admin/admin, then change password)
HTTP_AUTH=true
```

### `docker-compose.yml`

```yaml
services:

  tftp:
    build: ./tftp
    container_name: fileserver-tftp
    restart: unless-stopped
    network_mode: host
    volumes:
      - ${FILES_DIR:-./files}:/files

  sftp:
    build: ./sftp
    container_name: fileserver-sftp
    restart: unless-stopped
    ports:
      - "2222:22"
    environment:
      - SFTP_USER=${SFTP_USER:-lab}
      - SFTP_PASS=${SFTP_PASS:-lab}
    volumes:
      - ${FILES_DIR:-./files}:/chroot/files
      - sftp-hostkeys:/etc/ssh

  ftp:
    build: ./ftp
    container_name: fileserver-ftp
    restart: unless-stopped
    ports:
      - "21:21"
      - "${PASV_MIN:-21000}-${PASV_MAX:-21010}:${PASV_MIN:-21000}-${PASV_MAX:-21010}"
    volumes:
      - ${FILES_DIR:-./files}:/ftp
    environment:
      - FTP_USER=${FTP_USER:-lab}
      - FTP_PASS=${FTP_PASS:-lab}
      - PASV_ADDRESS=${PASV_ADDRESS:-10.33.1.38}
      - PASV_MIN=${PASV_MIN:-21000}
      - PASV_MAX=${PASV_MAX:-21010}

  http:
    image: filebrowser/filebrowser:latest
    container_name: fileserver-http
    restart: unless-stopped
    ports:
      - "8888:80"
    volumes:
      - ${FILES_DIR:-./files}:/srv
      - filebrowser-db:/database
    environment:
      - FB_NOAUTH=${HTTP_AUTH:-true}

volumes:
  sftp-hostkeys:
  filebrowser-db:
```

---

## 🔐 Authentication

### Auth matrix

| Service | Open (default) | Protected |
|---------|---------------|-----------|
| **TFTP** | Always open — no auth in protocol | Restrict at firewall only |
| **SFTP** | Set `SFTP_PASS=` (empty) to disable | Set `SFTP_USER` + `SFTP_PASS` in `.env` |
| **FTP** | Set `FTP_PASS=` (empty) | Set `FTP_USER` + `FTP_PASS` in `.env` |
| **HTTP** | `HTTP_AUTH=true` in `.env` | `HTTP_AUTH=false` + set password |

### Enable HTTP auth

```bash
# 1. Set in .env
HTTP_AUTH=false

# 2. Restart HTTP container
docker compose restart http

# 3. Login with admin/admin, then immediately change password
docker exec -it fileserver-http filebrowser users update admin --password yournewpass
```

### Changing credentials

```bash
# Edit .env
vim .env

# Restart affected service only
docker compose restart sftp
docker compose restart ftp
```

> **Note:** SFTP host keys persist in the `sftp-hostkeys` named volume across restarts.
> Clients will not see key-changed warnings unless you explicitly delete the volume.

---

## 🧪 Testing Each Service

### TFTP

```bash
clear
# Create a test file
echo "tftp-test" > files/tftp-test.txt

# Download test
tftp 10.33.1.38 -c get tftp-test.txt /tmp/tftp-retrieved.txt && echo "✓ TFTP GET OK"
cat /tmp/tftp-retrieved.txt

# Upload test
tftp 10.33.1.38 -c put /tmp/tftp-retrieved.txt tftp-upload-test.txt && echo "✓ TFTP PUT OK"
ls -la files/tftp-upload-test.txt
```

### SFTP

```bash
clear
# Clear any stale host key from previous containers
ssh-keygen -f '/home/bill/.ssh/known_hosts' -R '[localhost]:2222'

# Interactive session
sftp -P 2222 -o StrictHostKeyChecking=no lab@localhost
# sftp> ls files/
# sftp> put /tmp/localfile.txt files/
# sftp> get files/remotefile.txt /tmp/
# sftp> bye

# Non-interactive (requires sshpass)
sshpass -p 'lab' sftp -P 2222 -o StrictHostKeyChecking=no lab@localhost <<EOF
ls files/
bye
EOF
```

### FTP

```bash
clear
# Interactive
ftp localhost
# Name: lab
# Password: lab
# ftp> ls
# ftp> put localfile.txt
# ftp> get remotefile.txt
# ftp> bye

# One-liner upload
ftp localhost <<EOF
lab
lab
put /tmp/test.txt test.txt
ls
bye
EOF
```

> **FTP upload path note:** The remote path is relative to the chroot (`/ftp`).
> Use `put /local/path/file.txt remotename.txt` — do **not** use absolute remote paths.

### HTTP

```bash
clear
# Quick check
curl -s -o /dev/null -w "%{http_code}" http://localhost:8888
# Expected: 200

# Open in browser
xdg-open http://localhost:8888
# or
firefox http://localhost:8888 &
```

### All services — shared volume check

```bash
clear
# Touch a file and verify it appears across all services
touch files/shared-test.txt

# FTP
ftp localhost <<EOF
lab
lab
ls
bye
EOF

# SFTP
sshpass -p 'lab' sftp -P 2222 -o StrictHostKeyChecking=no lab@localhost <<EOF
ls files/
bye
EOF

# TFTP
tftp localhost -c get shared-test.txt /tmp/shared-test.txt && echo "✓ TFTP sees it"

# HTTP
curl -s http://localhost:8888/api/resources/ | grep shared-test
```

---

## 🔥 Firewall

### ⚠️ TFTP and ufw: Critical Behaviour

TFTP uses **ephemeral ports for data transfer**. The initial request goes to UDP/69, but tftpd responds from a random high port. With ufw's default `deny (incoming)` policy, this creates two distinct failure modes:

| Symptom | Cause |
|---------|-------|
| Client hangs, server sees no packets in tcpdump | Server firewall blocking UDP/69 inbound |
| Server sees packets, responds, client still hangs | **Client** firewall blocking ephemeral response ports |

The second case is the more surprising one — the client's firewall drops tftpd's reply because it arrives on an unexpected port and ufw treats it as a new unsolicited connection.

**The kernel conntrack helper `nf_conntrack_tftp` is required on both the server AND the client** to teach netfilter that ephemeral-port TFTP replies are RELATED to the original request.

```bash
# Load on server AND client
sudo modprobe nf_conntrack_tftp

# Make persistent across reboots (server and client)
echo 'nf_conntrack_tftp' | sudo tee /etc/modules-load.d/nf_conntrack_tftp.conf
```

Then allow RELATED,ESTABLISHED on both ends:

```bash
# Server and client — allow established/related (ufw persistent equivalent)
sudo iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

> **Note:** If `nf_conntrack_tftp` is loaded but conntrack still doesn't classify TFTP responses as RELATED (can happen with newer kernels), fall back to explicitly allowing UDP from the server on the client:
> ```bash
> sudo ufw allow from <server-ip> to any port 1024:65535 proto udp comment "TFTP responses"
> ```

---

### TFTP — Open to all (recommended for multi-subnet labs)

Subnet-scoped rules **will silently fail** when clients come from a different subnet. In a multi-subnet lab environment, just open TFTP:

```bash
clear
sudo ufw allow 69/udp comment "TFTP"
sudo ufw reload
```

Or scope to a specific interface if you have a defined internal NIC:

```bash
clear
# Replace wlan0/eth0 with your LAN interface
sudo ufw allow in on eth0 to any port 69 proto udp comment "TFTP LAN interface"
sudo ufw reload
```

### All other services — restrict to subnet

```bash
clear
sudo ufw allow from 10.33.1.0/24 to any port 21  proto tcp comment "FTP lab"
sudo ufw allow from 10.33.1.0/24 to any port 2222 proto tcp comment "SFTP lab"
sudo ufw allow from 10.33.1.0/24 to any port 8888 proto tcp comment "Fileserver HTTP"
sudo ufw allow from 10.33.1.0/24 to any port 21000:21010 proto tcp comment "FTP passive"
sudo ufw reload
```

### Verify rules

```bash
sudo ufw status numbered | grep -E "(69|21|2222|8888)"
```

---

## 🌐 Cisco IOS Usage

### Copy IOS image to device

```bash
# 1. Put the image in the shared files dir
cp /path/to/c2960-lanbasek9-mz.152-7.E6.bin files/

# 2. From Cisco IOS:
copy tftp flash
# Address or name of remote host? 10.33.1.38
# Source filename? c2960-lanbasek9-mz.152-7.E6.bin
# Destination filename? c2960-lanbasek9-mz.152-7.E6.bin
```

### Backup running config

```bash
# From Cisco IOS:
copy running-config tftp
# Address or name of remote host? 10.33.1.38
# Destination filename? router-hostname-backup.cfg

# Verify it landed
ls -la files/*.cfg
```

### Restore config

```bash
# From Cisco IOS:
copy tftp running-config
# Address or name of remote host? 10.33.1.38
# Source filename? router-hostname-backup.cfg
```

### Typical IOS TFTP troubleshooting

```
%Error opening tftp://10.33.1.38/file.bin (Timed out)
```

| Cause | Fix |
|-------|-----|
| TFTP container not using host networking | Verify `network_mode: host` in compose |
| File not in `files/` dir | Check `ls files/` on host |
| `files/` not world-readable | `chmod 777 files && chmod 644 files/*` |
| Firewall blocking UDP/69 on server | Add ufw rule — use open rule, not subnet-scoped (see Firewall section) |
| IOS device on different subnet than ufw rule | Subnet-scoped rules silently fail; open TFTP to all: `sudo ufw allow 69/udp` |
| `nf_conntrack_tftp` not loaded | `sudo modprobe nf_conntrack_tftp` on server |

---

## 🔧 Operations Reference

### Start / stop

```bash
clear
docker compose up -d          # Start all
docker compose down           # Stop all, keep volumes
docker compose down -v        # Stop all, DELETE volumes (loses sftp host keys + filebrowser db)
docker compose restart sftp   # Restart single service
```

### View logs

```bash
clear
docker compose logs -f                    # All services, follow
docker compose logs -f sftp              # Single service
docker compose logs --tail=50 ftp        # Last 50 lines
docker compose logs --since 1h           # Last hour
```

### Rebuild after config changes

```bash
clear
# After editing any Dockerfile, entrypoint.sh, sshd_config, or vsftpd.conf:
docker compose build --no-cache <service>
docker compose up -d <service>

# Example — rebuild just ftp:
docker compose build --no-cache ftp && docker compose up -d ftp
```

### Full nuke and rebuild

```bash
clear
docker compose down
docker rm -f $(docker ps -aq) 2>/dev/null
docker rmi -f $(docker images -aq) 2>/dev/null
docker volume prune -f
docker builder prune -af
docker compose build --no-cache
docker compose up -d
```

### Check container internals

```bash
# Inspect running filesystem
docker exec -it fileserver-sftp ls -la /chroot/
docker exec -it fileserver-ftp cat /etc/vsftpd.conf
docker exec -it fileserver-ftp cat /etc/shells

# Check user was created
docker exec -it fileserver-sftp id lab
docker exec -it fileserver-ftp id lab

# Shell into container
docker exec -it fileserver-ftp bash
docker exec -it fileserver-sftp bash
```

### Port binding verification

```bash
clear
ss -tulpn | grep -E "(21|69|2222|8888)"
```

Expected output:

```
udp   UNCONN  0.0.0.0:69     *        users:(("in.tftpd",...))
tcp   LISTEN  0.0.0.0:21     *        users:(("docker-proxy",...))
tcp   LISTEN  0.0.0.0:2222   *        users:(("docker-proxy",...))
tcp   LISTEN  0.0.0.0:8888   *        users:(("docker-proxy",...))
```

---

## 🛠 Troubleshooting

### TFTP

<details>
<summary><strong>Transfer times out or hangs — diagnosis workflow</strong></summary>

TFTP timeouts have several distinct root causes. Use tcpdump to identify which stage is failing before changing anything.

**Step 1 — Run tcpdump on the SERVER while client attempts transfer:**

```bash
# Watch all traffic to/from the client (not just port 69 — TFTP uses ephemeral ports for data)
sudo tcpdump -i any -n host <client-ip>
```

**Interpret results:**

| Server tcpdump shows | Meaning | Fix |
|----------------------|---------|-----|
| Nothing at all | Packet never arrives — routing issue or wrong IP | Check `ip route get <client-ip>` on server; verify client is sending to correct IP |
| `In` packets on port 69, no `Out` response | Server firewall blocking — ufw dropping before tftpd responds | See firewall section below |
| `In` packets on 69, `Out` packets on ephemeral port | Server is responding — **client firewall is dropping the reply** | Load `nf_conntrack_tftp` on client; allow RELATED,ESTABLISHED or add explicit ufw rule on client |

**Step 2 — Check server firewall:**

```bash
# Is default incoming policy deny?
sudo ufw status verbose | head -5
# "Default: deny (incoming)" = ufw will block TFTP responses by default

# Is nf_conntrack_tftp loaded?
lsmod | grep tftp
# If empty, load it:
sudo modprobe nf_conntrack_tftp

# Is RELATED,ESTABLISHED allowed?
sudo iptables -L INPUT -n | grep RELATED
```

**Step 3 — Check client firewall (easy to miss):**

```bash
# On the CLIENT machine:
sudo ufw status verbose | head -5
# If "deny (incoming)" — the client is blocking tftpd's ephemeral-port responses

# Load conntrack helper on client:
sudo modprobe nf_conntrack_tftp

# Allow RELATED,ESTABLISHED on client:
sudo iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# If conntrack still doesn't classify TFTP as RELATED, explicitly allow UDP from server:
sudo ufw allow from <server-ip> to any port 1024:65535 proto udp comment "TFTP responses"
sudo ufw reload
```

**Step 4 — Verify container and files:**

```bash
# Verify host networking is active
docker inspect fileserver-tftp | grep NetworkMode
# Expected: "host"

# Check tftpd is actually listening
ss -ulpn | grep 69

# Verify file permissions (tftpd runs as nobody)
ls -la files/
# Files must be world-readable: -rw-r--r-- or 644
chmod 644 files/*
chmod 777 files
```

**Make conntrack persistent across reboots (both server and client):**

```bash
echo 'nf_conntrack_tftp' | sudo tee /etc/modules-load.d/nf_conntrack_tftp.conf
```

</details>

<details>
<summary><strong>Subnet mismatch — client on different subnet than ufw rule</strong></summary>

This is a silent failure — ufw drops the packets without logging by default, and the client just sees a timeout.

```bash
# Confirm which subnet the client is actually on:
# (run on client)
ip addr show

# Check what your ufw rule allows:
sudo ufw status numbered | grep 69
```

If the client is on a different subnet (e.g., rule allows `10.33.1.0/24` but client is `10.71.1.x`), either update the rule or open TFTP fully:

```bash
# Open to all (recommended for multi-subnet labs)
sudo ufw allow 69/udp comment "TFTP"
sudo ufw reload

# Remove old subnet-scoped rule
sudo ufw status numbered | grep 69
sudo ufw delete <number>
```

</details>

<details>
<summary><strong>Uploads fail (PUT)</strong></summary>

```bash
# tftpd needs --create flag and world-writable directory
docker exec fileserver-tftp ps aux | grep tftpd
# Should show: in.tftpd -L --secure --create /files

chmod 777 files
```

</details>

---

### SFTP

<details>
<summary><strong>Host key warning / permission denied after rebuild</strong></summary>

```bash
# Clear cached host key
ssh-keygen -f '/home/bill/.ssh/known_hosts' -R '[localhost]:2222'

# Reconnect
sftp -P 2222 -o StrictHostKeyChecking=no lab@localhost
```

To prevent this across rebuilds, the `sftp-hostkeys` named volume persists `/etc/ssh`
between container restarts. Only `docker compose down -v` will regenerate keys.

</details>

<details>
<summary><strong>Hangs after password prompt</strong></summary>

This is the `atmoz/sftp` bug. If using the custom build and still seeing this:

```bash
# Verify sshd is running
docker exec fileserver-sftp ps aux | grep sshd

# Check chroot ownership — MUST be root:root 755
docker exec fileserver-sftp ls -la /chroot
# drwxr-xr-x root root  ← correct

# Check logs
docker compose logs sftp
```

</details>

<details>
<summary><strong>Permission denied on upload</strong></summary>

```bash
# files dir inside chroot must be owned by the user
docker exec fileserver-sftp ls -la /chroot/
# drwxr-xr-x root root  /chroot      ← correct
# drwxr-xr-x lab  root  /chroot/files ← correct

# If wrong, entrypoint.sh sets this — rebuild
docker compose build --no-cache sftp && docker compose up -d sftp
```

</details>

---

### FTP

<details>
<summary><strong>530 Login incorrect</strong></summary>

```bash
# Check user was created
docker exec fileserver-ftp id lab

# Check /etc/shells contains /bin/false
docker exec fileserver-ftp grep false /etc/shells
# If missing, entrypoint didn't run correctly — rebuild
docker compose build --no-cache ftp && docker compose up -d ftp
```

</details>

<details>
<summary><strong>Connects but file transfers hang (PASV issues)</strong></summary>

```bash
# Verify PASV_ADDRESS matches the IP you're connecting FROM
docker exec fileserver-ftp grep pasv /etc/vsftpd.conf

# If wrong, update .env and restart
vim .env   # fix PASV_ADDRESS
docker compose restart ftp

# Verify passive port range is published
docker compose ps ftp
# Should show: 0.0.0.0:21000-21010->21000-21010/tcp
```

</details>

<details>
<summary><strong>553 Could not create file</strong></summary>

```bash
# Upload path is relative to chroot (/ftp)
# Wrong:  put file.txt /tmp/file.txt
# Right:  put file.txt file.txt

# Also verify write permissions
docker exec fileserver-ftp ls -la /ftp
```

</details>

---

### HTTP

<details>
<summary><strong>Opens in w3m instead of browser</strong></summary>

```bash
# Set default browser
xdg-settings set default-web-browser firefox-esr.desktop

# Or launch directly
firefox http://localhost:8888 &
```

</details>

<details>
<summary><strong>Auth not working after changing HTTP_AUTH</strong></summary>

```bash
# FB_NOAUTH=true  → no login (open)
# FB_NOAUTH=false → login required
# The env var name is inverted from what you'd expect

# Restart after .env change
docker compose restart http
```

</details>

---

## 🔒 Security Notes

> This stack is designed for **isolated lab environments** on a trusted LAN.
> It is **not** suitable for internet-facing deployment without significant hardening.

| Risk | Mitigation |
|------|-----------|
| TFTP has no auth | Open to all on LAN (subnet rules break multi-subnet labs); bind to specific interface for tighter control |
| FTP sends credentials in plaintext | Use SFTP for anything sensitive; FTP only for legacy device compat |
| Default credentials | Change `lab`/`lab` in `.env` before deployment |
| HTTP filebrowser default admin/admin | Enable auth (`HTTP_AUTH=false`) and change password immediately |
| TFTP `--create` allows arbitrary uploads | Expected for lab use; remove flag if read-only is sufficient |

### Bind TFTP to specific interface (optional hardening)

```bash
# In tftp/Dockerfile, change ENTRYPOINT to bind to specific IP:
ENTRYPOINT ["in.tftpd", "-L", "--secure", "--create", "--address", "10.33.1.38", "/files"]
```

---

## 📄 File Reference

### `tftp/Dockerfile`

```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    tftpd-hpa \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 69/udp
ENTRYPOINT ["in.tftpd", "-L", "--secure", "--create", "/files"]
```

### `sftp/Dockerfile`

```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd
COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
```

### `sftp/sshd_config`

```
Port 22
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
Subsystem sftp internal-sftp
Match User lab
    ChrootDirectory /chroot
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

### `sftp/entrypoint.sh`

```bash
#!/bin/bash
set -e

SFTP_USER=${SFTP_USER:-lab}
SFTP_PASS=${SFTP_PASS:-lab}

[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
[ -f /etc/ssh/ssh_host_rsa_key ]     || ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''

mkdir -p /chroot/files
chown root:root /chroot
chmod 755 /chroot

useradd -M -d /chroot -s /bin/false -u 1000 "$SFTP_USER" 2>/dev/null || true
echo "$SFTP_USER:$SFTP_PASS" | chpasswd

chown "$SFTP_USER":root /chroot/files
chmod 755 /chroot/files

exec /usr/sbin/sshd -D -e
```

### `ftp/Dockerfile`

```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    vsftpd \
    && rm -rf /var/lib/apt/lists/*
COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 21
ENTRYPOINT ["/entrypoint.sh"]
```

### `ftp/vsftpd.conf`

```ini
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
pasv_enable=YES
# pasv_address, pasv_min_port, pasv_max_port injected by entrypoint
```

### `ftp/entrypoint.sh`

```bash
#!/bin/bash
set -e

FTP_USER=${FTP_USER:-lab}
FTP_PASS=${FTP_PASS:-lab}
PASV_ADDRESS=${PASV_ADDRESS:-127.0.0.1}
PASV_MIN=${PASV_MIN:-21000}
PASV_MAX=${PASV_MAX:-21010}

# pam_shells.so rejects /bin/false unless listed in /etc/shells
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
```

---

## 🏷 Quick Reference Card

```
SERVICE   PORT        CREDS           NOTES
──────────────────────────────────────────────────────
TFTP      UDP/69      none            --create enabled; world-writable files/
SFTP      TCP/2222    lab / lab       StrictHostKeyChecking=no on first connect
FTP       TCP/21      lab / lab       Passive mode; PASV_ADDRESS must match LAN IP
HTTP      TCP/8888    admin / admin   FB_NOAUTH=true = open; false = login required

HOST      10.33.1.38
FILES     /opt/docker/xftp/files/
COMPOSE   /opt/docker/xftp/docker-compose.yml
ENV       /opt/docker/xftp/.env
```

---

*Generated for MX Linux 25 (Debian Trixie) · Docker Compose v2 · `debian:bookworm-slim` base*
