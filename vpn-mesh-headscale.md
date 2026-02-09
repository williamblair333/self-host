# 🌐 Self-Hosted Private Mesh VPN (Headscale + Caddy)

**Repository:** `williamblair333/debian-howto-guides`
**OS Target:** Debian Trixie (Testing)
**Style:** RHCSA-aligned (firewalld, systemd, hardening)

---

## 📖 Overview
This guide details how to build a **$0/month** private mesh VPN using [Headscale](https://github.com/juanfont/headscale)—an open-source, self-hosted implementation of the Tailscale coordination server.

We will deploy this on **Oracle Cloud's Always Free** tier using **Debian Trixie**, utilizing **Caddy** for automatic SSL management and **firewalld** for enterprise-grade network security.

### 🌟 Features
* **Unlimited Devices & Users:** No seat limits like the commercial SaaS tier.
* **Split DNS & MagicDNS:** Resolve devices by hostname (e.g., `ping database`).
* **Direct P2P Connectivity:** Low latency, high throughput (WireGuard).
* **Automatic HTTPS:** Zero-config SSL via Let's Encrypt.

---

## 🛠️ Prerequisites

1.  **VPS Provider:** Oracle Cloud Infrastructure (OCI) "Always Free".
    * **Shape:** `VM.Standard.A1.Flex` (ARM Ampere).
    * **Specs:** 4 OCPUs, 24 GB RAM.
    * **OS Image:** Debian 12 (Bookworm) upgraded to Trixie, or a custom Trixie image.
2.  **Domain Name:** A subdomain (e.g., `vpn.example.com`) pointing to your VPS Public IP.
3.  **Local Machine:** SSH client installed.

---

## 1. ☁️ Infrastructure & Cloud Networking

Before touching the OS, we must open the "Virtual Cloud Network" (VCN) firewall in the Oracle Console.

**Navigate to:** `Networking` -> `Virtual Cloud Networks` -> `Your VCN` -> `Security Lists` -> `Default Security List`.

**Add Ingress Rules:**

| Source CIDR | IP Protocol | IP Protocol | Destination Port | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `0.0.0.0/0` | TCP | 6 | `22` | SSH Access |
| `0.0.0.0/0` | TCP | 6 | `80, 443` | Web/SSL (Caddy) |
| `0.0.0.0/0` | UDP | 17 | `3478, 41641` | DERP & WireGuard P2P |

---

## 2. 🛡️ Host Security & Hardening (RHCSA Style)

We will use **`firewalld`** (standard on RHEL/CentOS) instead of `ufw` or raw `nftables`.

### 2.1 Install & Configure Firewalld
```bash
# 1. Install Firewalld
sudo apt update && sudo apt install firewalld -y

# 2. Start and Enable the service
sudo systemctl enable --now firewalld

# 3. Allow SSH (Prevent lockout)
sudo firewall-cmd --permanent --add-service=ssh

# 4. Allow HTTP/HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 5. Allow Headscale WireGuard & STUN ports
sudo firewall-cmd --permanent --add-port=41641/udp
sudo firewall-cmd --permanent --add-port=3478/udp

# 6. Reload to apply changes
sudo firewall-cmd --reload
```

### 2.2 SSH Hardening
Disable password authentication to prevent brute-force attacks.

1.  **Local Machine:** Generate and copy your key.
    ```bash
    ssh-keygen -t ed25519 -C "headscale-admin"
    ssh-copy-id -i ~/.ssh/id_ed25519.pub debian@<YOUR_VPS_IP>
    ```

2.  **VPS:** Edit `/etc/ssh/sshd_config`.
    ```bash
    # Ensure these lines are set
    PasswordAuthentication no
    PermitRootLogin prohibit-password
    PubkeyAuthentication yes
    ```

3.  **Restart SSH:**
    ```bash
    sudo systemctl restart ssh
    ```

### 2.3 Fail2Ban (Intrusion Prevention)
Install Fail2Ban to ban IPs that repeatedly fail SSH login attempts.
```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```
*Note: Debian's default Fail2Ban config works out-of-the-box for SSH.*

---

## 3. 🐳 Core Deployment (Docker Compose)

We will run Headscale and Caddy in containers for easy management and upgrades.

### 3.1 Install Docker Engine
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

### 3.2 Prepare Directory Structure
```bash
mkdir -p ~/headscale/config
mkdir -p ~/headscale/data
cd ~/headscale
```

### 3.3 Configuration Files

#### `docker-compose.yml`
Create this file in `~/headscale/`:
```yaml
services:
  headscale:
    image: headscale/headscale:latest
    container_name: headscale
    restart: unless-stopped
    volumes:
      - ./config:/etc/headscale
      - ./data:/var/lib/headscale
    # Headscale listens internally on 8080
    command: headscale serve

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - ACME_AGREE=true

volumes:
  caddy_data:
  caddy_config:
```

#### `Caddyfile`
Create this file in `~/headscale/`:
*(Replace `vpn.example.com` with your actual domain)*
```caddy
vpn.example.com {
    reverse_proxy headscale:8080
}
```

#### `config/config.yaml`
1.  Download the official template:
    ```bash
    wget -O config/config.yaml [https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml](https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml)
    ```
2.  **Edit the file** (`nano config/config.yaml`) and change these key values:
    ```yaml
    server_url: [https://vpn.example.com](https://vpn.example.com)
    listen_addr: 0.0.0.0:8080
    metrics_listen_addr: 127.0.0.1:9090
    
    # Paths (Must match docker-compose volumes)
    private_key_path: /var/lib/headscale/private.key
    db_type: sqlite3
    db_path: /var/lib/headscale/db.sqlite
    
    # Optional: Enable MagicDNS
    dns_config:
      magic_dns: true
      base_domain: example.net
    ```

### 3.4 Start the Stack
```bash
docker compose up -d
```
Check logs with `docker compose logs -f`.

---

## 4. 💻 Client Configuration

Headscale is compatible with standard Tailscale clients, but you must override the "Login Server" URL.

### 🐧 Linux
```bash
# Install Tailscale
curl -fsSL [https://tailscale.com/install.sh](https://tailscale.com/install.sh) | sh

# Login with custom server flag
sudo tailscale login --login-server [https://vpn.example.com](https://vpn.example.com)
```
*You will be given a URL. Click it, but since you are self-hosted, see Section 5 below on how to approve it.*

### 🪟 Windows
1.  Close Tailscale completely (Right-click tray icon -> Exit).
2.  Open **PowerShell** as Administrator.
3.  Run:
    ```powershell
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Tailscale IPN' -Name UnattendedURL -PropertyType String -Value '[https://vpn.example.com](https://vpn.example.com)' -Force
    ```
4.  Restart Tailscale and click **Log in**.

### 🍏 iOS / 🤖 Android
1.  **Android:** Open App -> Tap "three dots" menu 10 times -> **Change Server** -> Enter `https://vpn.example.com`.
2.  **iOS:** Open Settings App -> Scroll down to **Tailscale** -> **Reset Server** (Toggle On) -> Open App -> Enter "Alternate Coordination Server" URL.

---

## 5. ⚡ Management & Authorization

Since there is no GUI by default, you manage users via the CLI on the VPS.

### Creating a User (Namespace)
```bash
docker exec headscale headscale users create my-admin
```

### Registering a Machine
When a client logs in, they get a "Machine Key". You can verify them via the CLI.

1.  **List Pending Nodes:**
    ```bash
    docker exec headscale headscale nodes list
    ```
2.  **Register a Node:**
    ```bash
    docker exec headscale headscale nodes register --user my-admin --key nodekey:abc123...
    ```

### Pre-Authenticated Keys (Best for Servers)
Skip the manual approval step by generating a key:
```bash
docker exec headscale headscale preauthkeys create -e 24h --user my-admin
```
*Use this key with `tailscale up --authkey <KEY> --login-server <URL>`.*

---

## 6. 🚀 Optimization: Ensuring Direct P2P

We want to avoid "DERP Relays" (bouncing traffic through the VPS) to save bandwidth and reduce latency.

1.  **Check Connection Mode:**
    On a client, run:
    ```bash
    tailscale status
    ```
    If it says `relay`, you are using the VPS bandwidth. If it says `direct`, you are P2P.

2.  **Troubleshooting:**
    * Ensure UDP port `41641` is open on the VPS firewall (we did this in Step 2).
    * Ensure your home router supports **UPnP** or manually forward UDP `41641` to your local computer's IP.
    * **Force Discovery:** Run `tailscale ping <peer-ip>`.

---

## 7. 🧹 Maintenance & Updates

### Auto-Updates (Unattended Upgrades)
Debian Trixie is a rolling/testing release. Keep it secure automatically.
```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Backup
Periodically backup your `~/headscale/data` directory. It contains your private keys and the SQLite database of all your nodes.