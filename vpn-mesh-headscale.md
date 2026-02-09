# 🌐 Self-Hosted Private Mesh VPN (Headscale + Caddy)

**Repository:** `williamblair333/debian-howto-guides`
**OS Target:** Debian 13 (Trixie) - Stable
**Style:** RHCSA-aligned (firewalld, systemd, hardening)

---

## 📖 Overview
This guide details how to build a private mesh VPN using [Headscale](https://github.com/juanfont/headscale)—the open-source, self-hosted implementation of the Tailscale coordination server.

This setup avoids major cloud providers (Oracle/AWS/GCP) in favor of independent infrastructure, running on **Debian 13 (Trixie)**. We utilize **Caddy** for automatic SSL management and **firewalld** for enterprise-grade network security.

### 🌟 Features
* **Privacy Focused:** Host on independent infrastructure (Hetzner, etc.).
* **Unlimited Devices:** No seat limits.
* **Direct P2P:** WireGuard mesh networking.
* **Split DNS:** Resolve local services by name.

---

## 1. 🏗️ Infrastructure: The "No Big Tech" Approach

Since we are avoiding the "Big 3" free tiers, we look for high-trust, low-cost independent providers.

### Recommended Providers
1.  **Hetzner Cloud (Top Choice):** German-based, privacy-focused, incredible performance.
    * **Cost:** ~$5/month (Cloud CX22).
    * **Location:** Germany, Finland, or USA (Ashburn/Hillsboro).
    * **Specs:** Plenty for Headscale (2 vCPU, 4GB RAM is standard entry now).
2.  **"LowEndBox" Deals:**
    * Check sites like [LowEndBox](https://lowendbox.com) for "Annual VPS Deals".
    * You can often find providers like **RackNerd** or **GreenCloud** offering instances for **$10–$15 per year** (approx $1/mo).
    * **Requirement:** Ensure you get at least 1GB RAM and a dedicated IPv4 address.

### 1.1 DNS Configuration
Regardless of the provider, you need a domain (e.g., `vpn.example.com`).
1.  **A Record:** Point `vpn.example.com` to your VPS IPv4 address.
2.  **AAAA Record:** (Optional) Point to your VPS IPv6 address.

---

## 2. 🛡️ Host Security & Hardening (RHCSA Style)

We use **`firewalld`** (standard on RHEL/Debian) for managing the firewall zones.

### 2.1 Install & Configure Firewalld
Debian 13 uses `nftables` backend by default, which `firewalld` manages perfectly.

```bash
# 1. Update and Install
sudo apt update && sudo apt upgrade -y
sudo apt install firewalld -y

# 2. Start and Enable
sudo systemctl enable --now firewalld

# 3. Allow SSH (Prevent lockout)
sudo firewall-cmd --permanent --add-service=ssh

# 4. Allow HTTP/HTTPS (For Caddy/SSL)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 5. Allow Headscale WireGuard (UDP) & STUN
# 41641 is the default Headscale UDP port for P2P traffic
sudo firewall-cmd --permanent --add-port=41641/udp
sudo firewall-cmd --permanent --add-port=3478/udp

# 6. Reload to apply
sudo firewall-cmd --reload
```

### 2.2 SSH Hardening
1.  **Local Machine:** Generate a keypair.
    ```bash
    ssh-keygen -t ed25519 -C "vpn-admin"
    ssh-copy-id -i ~/.ssh/id_ed25519.pub user@<VPS_IP>
    ```
2.  **VPS:** Disable password login (`/etc/ssh/sshd_config`).
    ```bash
    PasswordAuthentication no
    PermitRootLogin prohibit-password
    PubkeyAuthentication yes
    ```
3.  **Restart SSH:** `sudo systemctl restart ssh`

### 2.3 Fail2Ban
Crucial for public-facing VPS.
```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

---

## 3. 🐳 Core Deployment (Docker Compose)

### 3.1 Install Docker Engine (Debian 13 Trixie)
```bash
# Remove conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) \
  trixie stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

### 3.2 Directory Setup
```bash
mkdir -p ~/headscale/config
mkdir -p ~/headscale/data
cd ~/headscale
```

### 3.3 `docker-compose.yml`
Create this file in `~/headscale/`.
```yaml
services:
  headscale:
    image: headscale/headscale:latest
    container_name: headscale
    restart: unless-stopped
    volumes:
      - ./config:/etc/headscale
      - ./data:/var/lib/headscale
    # Headscale runs on 8080 internally; Caddy handles the public 443
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

### 3.4 `Caddyfile`
Create this file in `~/headscale/`. Replace `vpn.example.com` with your domain.
```caddy
vpn.example.com {
    reverse_proxy headscale:8080
}
```

### 3.5 `config.yaml`
1.  Download the template:
    ```bash
    wget -O config/config.yaml [https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml](https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml)
    ```
2.  **Essential Edits:**
    ```yaml
    server_url: [https://vpn.example.com](https://vpn.example.com)
    listen_addr: 0.0.0.0:8080
    metrics_listen_addr: 127.0.0.1:9090
    
    private_key_path: /var/lib/headscale/private.key
    db_type: sqlite3
    db_path: /var/lib/headscale/db.sqlite
    
    # Optional: Enable MagicDNS
    dns_config:
      magic_dns: true
      base_domain: example.net
    ```

### 3.6 Start Service
```bash
docker compose up -d
```

---

## 4. 💻 Client Configuration

Standard Tailscale clients work by simply overriding the login server URL.

### 🐧 Linux
```bash
# Install Tailscale
curl -fsSL [https://tailscale.com/install.sh](https://tailscale.com/install.sh) | sh

# Login with custom server flag
sudo tailscale login --login-server [https://vpn.example.com](https://vpn.example.com)
```

### 🪟 Windows
1.  Close Tailscale.
2.  Open **PowerShell (Admin)**.
3.  Set the override registry key:
    ```powershell
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Tailscale IPN' -Name UnattendedURL -PropertyType String -Value '[https://vpn.example.com](https://vpn.example.com)' -Force
    ```
4.  Restart Tailscale and Login.

### 🍏 iOS / 🤖 Android
1.  **Android:** Open App → Tap "three dots" menu repeatedly (10x) → **Change Server** → Enter `https://vpn.example.com`.
2.  **iOS:** Settings → Tailscale → **Reset Server** (Toggle On) → Open App → Enter "Alternate Coordination Server" URL.

---

## 5. ⚡ Management & P2P Optimization

### User Management
Since Headscale is CLI-based, you run commands inside the Docker container.

* **Create Namespace:** `docker exec headscale headscale users create my-admin`
* **Generate Pre-Auth Key:** `docker exec headscale headscale preauthkeys create -e 24h --user my-admin`
* **List Nodes:** `docker exec headscale headscale nodes list`

### Ensuring Direct P2P (No Relay)
We want to avoid routing traffic through your VPS to save bandwidth.

1.  **Check Status:** `tailscale status` on a client.
    * `direct` = Good (P2P).
    * `relay` = Bad (Using VPS bandwidth).
2.  **Fixing Relay:**
    * Verify VPS Firewall allows UDP `41641`.
    * **Home Routers:** Enable UPnP or forward UDP `41641` to your desktop/laptop IP.
    * **Test:** `tailscale ping <node-ip>` forces NAT traversal attempts.

---

## 6. 🧹 Maintenance (Debian 13)

### Unattended Upgrades
Keep the system patched automatically.
```bash
sudo apt install unattended-upgrades -y
# Standard Debian config usually enables this by default, verify with:
systemctl status unattended-upgrades
```

### Backups
Backup the `~/headscale/data/db.sqlite` file. This is the "brain" of your network.
