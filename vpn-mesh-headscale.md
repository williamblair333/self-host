# 🌐 Self-Hosted Private Mesh VPN (Headscale + Caddy)

**Repository:** `williamblair333/debian-howto-guides`
**OS Target:** Debian 13 (Trixie) - Stable
**Style:** RHCSA-aligned (firewalld, systemd)

---

## 📖 Overview
This guide details how to build a private mesh VPN using [Headscale](https://github.com/juanfont/headscale)—the open-source, self-hosted implementation of the Tailscale coordination server.

This setup avoids "Big Tech" cloud providers in favor of independent infrastructure (e.g., Hetzner, LowEndBox), running on **Debian 13 (Trixie)**. We utilize **Caddy** within the Docker stack for automatic, zero-config SSL management.

### 🌟 Features
* **Privacy Focused:** Host on independent infrastructure.
* **Unlimited Devices:** No seat limits.
* **Direct P2P:** WireGuard mesh networking.
* **Split DNS:** Resolve local services by name.

---

## 🛠️ Prerequisites

1.  **Infrastructure:** A VPS with a static IPv4 address.
    * *Recommendation:* **Hetzner Cloud** (CPX11/CX22) or a trusted "LowEndBox" deal (~$15/yr).
    * *Specs:* 1GB RAM minimum.
2.  **Domain Name:** A subdomain (e.g., `vpn.example.com`) pointing to your VPS Public IP.
3.  **Docker Environment:**
    * You **must** have Docker and Docker Compose installed before proceeding.
    * 👉 **Follow this guide:** [Debian Docker Setup Guide](https://github.com/williamblair333/debian-howto-guides/blob/main/debian-docker-setup-guide.md)

---

## 1. 🛡️ Host Security & Hardening (RHCSA Style)

We use **`firewalld`** (standard on RHEL/Debian) for managing the firewall zones.

### 1.1 Install & Configure Firewalld
Debian 13 uses `nftables` backend by default, which `firewalld` manages abstractly.

```bash
# 1. Update and Install
sudo apt update && sudo apt upgrade -y
sudo apt install firewalld -y

# 2. Start and Enable
sudo systemctl enable --now firewalld

# 3. Allow SSH (Prevent lockout)
sudo firewall-cmd --permanent --add-service=ssh

# 4. Allow HTTP/HTTPS (For Caddy SSL challenges)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 5. Allow Headscale WireGuard (UDP) & STUN
# Port 41641 is critical for direct P2P connections (no relay)
sudo firewall-cmd --permanent --add-port=41641/udp
sudo firewall-cmd --permanent --add-port=3478/udp

# 6. Reload to apply
sudo firewall-cmd --reload
```

### 1.2 SSH Hardening
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

### 1.3 Fail2Ban
Crucial for public-facing VPS.
```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

---

## 2. 🐳 Core Deployment (Docker Compose)

We will deploy Headscale alongside a minimal Caddy container.
*Note: For advanced Caddy configurations, see the dedicated Caddy guide (coming soon).*

### 2.1 Directory Setup
```bash
mkdir -p ~/headscale/config
mkdir -p ~/headscale/data
cd ~/headscale
```

### 2.2 `docker-compose.yml`
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

### 2.3 `Caddyfile`
Create this file in `~/headscale/`. This config tells Caddy to fetch a certificate for your domain and proxy traffic to the Headscale container.

*(Replace `vpn.example.com` with your actual domain)*

```caddy
vpn.example.com {
    reverse_proxy headscale:8080
}
```

### 2.4 `config.yaml`
1.  Download the template:
    ```bash
    wget -O config/config.yaml [https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml](https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml)
    ```
2.  **Essential Edits:** Open `config/config.yaml` and modify these lines:

    ```yaml
    # 1. The public URL clients will use to connect
    server_url: [https://vpn.example.com](https://vpn.example.com)

    # 2. Listen on all interfaces (Docker handles the mapping)
    listen_addr: 0.0.0.0:8080
    
    # 3. Database and Key paths (Must match Docker volumes)
    private_key_path: /var/lib/headscale/private.key
    db_type: sqlite3
    db_path: /var/lib/headscale/db.sqlite
    
    # 4. Optional: Enable MagicDNS
    dns_config:
      magic_dns: true
      base_domain: example.net
    ```

### 2.5 Start the Stack
```bash
docker compose up -d
```
Check logs with `docker compose logs -f` to ensure Caddy successfully obtained an SSL certificate.

---

## 3. 💻 Client Configuration

Headscale is compatible with standard Tailscale clients. You simply need to override the **Coordination Server URL**.

### 🐧 Linux
```bash
# Install Tailscale
curl -fsSL [https://tailscale.com/install.sh](https://tailscale.com/install.sh) | sh

# Login with custom server flag
sudo tailscale login --login-server [https://vpn.example.com](https://vpn.example.com)
```

### 🪟 Windows
1.  Close Tailscale completely (Right-click tray icon -> Exit).
2.  Open **PowerShell (Admin)**.
3.  Set the override registry key:
    ```powershell
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Tailscale IPN' -Name UnattendedURL -PropertyType String -Value '[https://vpn.example.com](https://vpn.example.com)' -Force
    ```
4.  Restart Tailscale and click **Log in**.

### 🍏 iOS / 🤖 Android
1.  **Android:** Open App → Tap "three dots" menu repeatedly (10x) → **Change Server** → Enter `https://vpn.example.com`.
2.  **iOS:** Settings → Tailscale → **Reset Server** (Toggle On) → Open App → Enter "Alternate Coordination Server" URL.

---

## 4. ⚡ Management & P2P Optimization

### User Management (CLI)
Since Headscale is headless, you manage it via `docker exec`.

* **Create a User (Namespace):**
  ```bash
  docker exec headscale headscale users create my-admin
  ```
* **Generate Pre-Auth Key (For Servers/Headless Nodes):**
  ```bash
  docker exec headscale headscale preauthkeys create -e 24h --user my-admin
  ```
* **List Connected Nodes:**
  ```bash
  docker exec headscale headscale nodes list
  ```

### Ensuring Direct P2P (No Relay)
We want to avoid routing traffic through your VPS (DERP Relay) to save bandwidth and reduce latency.

1.  **Check Status:** Run `tailscale status` on a client.
    * `direct` = **Good** (P2P).
    * `relay` = **Bad** (Using VPS bandwidth).
2.  **Fixing Relay Issues:**
    * Verify VPS Firewall allows UDP `41641`.
    * **Home Routers:** Enable UPnP or manually forward UDP `41641` to your local machine's IP.
    * **Test:** `tailscale ping <node-ip>` forces a P2P path discovery attempt.

---

## 5. 🧹 Maintenance (Debian 13)

### Unattended Upgrades
Keep the system patched automatically.
```bash
sudo apt install unattended-upgrades -y
# Verify status
systemctl status unattended-upgrades
```

### Backups
The entire state of your VPN is contained in the `./data` folder.
* **Critical File:** `~/headscale/data/db.sqlite`
* **Strategy:** Add a cron job to copy this file to a secure location (e.g., S3 or Rclone) nightly.
