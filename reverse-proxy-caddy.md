# 🚦 Ultimate Caddy Web Server & Reverse Proxy Guide

**Repository:** `williamblair333/debian-howto-guides`
**OS Target:** Debian 13 (Trixie) - Stable
**Style:** Docker-First, Production-Ready, Security-Hardened

---

## 📖 Overview
[Caddy](https://caddyserver.com/) is the modern standard for self-hosted web servers. Unlike Nginx or Apache, Caddy provides **Automatic HTTPS** (via Let's Encrypt) by default with zero configuration.

This guide will set up Caddy as your **Main Gateway**. It will handle SSL termination and route traffic to your other Docker containers (Headscale, Nextcloud, Plex, etc.) securely.

### 🌟 Why Caddy?
* **Automatic HTTPS:** It obtains and renews certificates automatically.
* **Memory Safe:** Written in Go, protecting against buffer overflows.
* **Simple Syntax:** The `Caddyfile` is human-readable and concise.
* **Modern Protocols:** HTTP/3 and QUIC support out of the box.

---

## 🛠️ Prerequisites

1.  **Infrastructure:** A VPS or Home Server (Debian 13 Trixie).
2.  **Domain Name:** A domain (e.g., `example.com`) pointing to your server's Public IP.
3.  **Docker Environment:**
    * You **must** have Docker installed.
    * 👉 **Follow this guide:** [Debian Docker Setup Guide](https://github.com/williamblair333/debian-howto-guides/blob/main/debian-docker-setup-guide.md)

---

## 1. 🛡️ Network & Firewall Setup (Firewalld)

Before deploying, ensure your server can accept web traffic.

```bash
# 1. Install Firewalld (if not already done)
sudo apt update && sudo apt install firewalld -y
sudo systemctl enable --now firewalld

# 2. Open Web Ports
# Port 80 is required for Let's Encrypt HTTP challenges
# Port 443 is for secure HTTPS traffic
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 3. Reload Rules
sudo firewall-cmd --reload
```

---

## 2. 🐳 Core Deployment (Docker Compose)

We will create a centralized "Caddy Gateway" stack.

### 2.1 Directory Structure
We organize persistence data to ensure certificates survive container restarts.

```bash
mkdir -p ~/caddy_gateway/config
mkdir -p ~/caddy_gateway/data
mkdir -p ~/caddy_gateway/site  # For static files (optional)
cd ~/caddy_gateway
```

### 2.2 `docker-compose.yml`
Create this file in `~/caddy_gateway/`.

```yaml
services:
  caddy:
    image: caddy:latest
    container_name: caddy_gateway
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp" # Required for HTTP/3 (QUIC)
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./site:/srv
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy_net

networks:
  caddy_net:
    external: true
    name: caddy_net

volumes:
  caddy_data:
  caddy_config:
```

### 2.3 Create the Network
We use an external Docker network so *other* containers (like Headscale, Nextcloud) can talk to Caddy without being in the same Compose file.

```bash
docker network create caddy_net
```

---

## 3. 📝 The Caddyfile Configuration

The `Caddyfile` is where the magic happens. We will use a modular approach with "Snippets" to keep it clean.

Create `~/caddy_gateway/Caddyfile`:

```caddy
{
    # Global Options
    email your-email@example.com  # Critical for Let's Encrypt notifications
    # debug                       # Uncomment for verbose logs during troubleshooting
}

# ---------------------------------------------------------
# 🛡️ SNIPPETS (Reusable Blocks)
# ---------------------------------------------------------

(secure_headers) {
    header {
        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"
        # Prevent MIME-sniffing
        X-Content-Type-Options "nosniff"
        # Enable XSS protection
        X-XSS-Protection "1; mode=block"
        # Strict Transport Security (HSTS) - 1 year
        Strict-Transport-Security "max-age=31536000;"
        # Remove Caddy version info (Security by obscurity)
        -Server
    }
}

(log_json) {
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 5
            roll_keep_for 720h
        }
        format json
    }
}

# ---------------------------------------------------------
# 🌐 SITES & SERVICES
# ---------------------------------------------------------

# 1. Static "Landing Page" (example.com)
example.com {
    import secure_headers
    root * /srv
    file_server
}

# 2. Reverse Proxy: Headscale VPN
# Ensure your Headscale container is connected to 'caddy_net'
vpn.example.com {
    import secure_headers
    reverse_proxy headscale:8080
}

# 3. Reverse Proxy: Whoami (Test Service)
# A simple way to verify everything works
whoami.example.com {
    import secure_headers
    reverse_proxy whoami_container:80
}
```

### 2.4 Start the Gateway
```bash
docker compose up -d
```
Your server is now live. Caddy will automatically fetch certificates for any domain defined in the `Caddyfile`.

---

## 4. 🔗 Connecting Other Services

To expose a new service (e.g., a Nextcloud container) through this gateway, you do not need to edit the Nextcloud compose file's ports.

1.  **Add the container to `caddy_net`:**
    In your *other* `docker-compose.yml` (e.g., for Nextcloud):
    ```yaml
    services:
      nextcloud:
        image: nextcloud
        networks:
          - caddy_net  # Connect to the gateway network
    
    networks:
      caddy_net:
        external: true
    ```

2.  **Update the `Caddyfile`:**
    ```caddy
    cloud.example.com {
        import secure_headers
        reverse_proxy nextcloud:80
    }
    ```

3.  **Reload Caddy (Zero Downtime):**
    You don't need to restart the container. Just reload the config:
    ```bash
    docker exec -w /etc/caddy caddy_gateway caddy reload
    ```

---

## 5. 🧠 Advanced: Wildcard Certs & DNS Challenge
*Recommended if your server is behind a home firewall or if you want to hide your origin IP.*

By default, Caddy uses **HTTP Validation** (Port 80). If you cannot open Port 80, or want a wildcard cert (`*.example.com`), you need the **DNS Challenge**.

*Note: This requires a custom Caddy build with a plugin for your DNS provider (Cloudflare, Route53, etc).*

1.  **Create a `Dockerfile`:**
    ```dockerfile
    FROM caddy:builder AS builder
    RUN xcaddy build \
        --with [github.com/caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare)

    FROM caddy:latest
    COPY --from=builder /usr/bin/caddy /usr/bin/caddy
    ```
2.  **Update Compose:** Build from this Dockerfile instead of pulling `image: caddy:latest`.
3.  **Update Caddyfile:**
    ```caddy
    *.example.com {
        tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        @vpn host vpn.example.com
        handle @vpn {
            reverse_proxy headscale:8080
        }
    }
    ```

---

## 6. 🚨 Troubleshooting

### "It's not working!" Checklist:
1.  **DNS Propagation:** Did you actually point `vpn.example.com` to your IP? Check with `dig vpn.example.com`.
2.  **Firewall:** Is Port 80/443 actually open?
    * Test: `curl -v http://YOUR_IP` (Should show a redirect or Caddy page).
3.  **Logs:** Caddy tells you exactly why SSL failed.
    ```bash
    docker compose logs -f --tail=50
    ```
    *Look for lines containing `error` or `challenge failed`.*

### Common Errors:
* **`acme: error: 429`:** You hit Let's Encrypt rate limits (usually 5 failures per hour). Switch to `tls internal` in your Caddyfile temporarily to test config without burning limits.
* **`502 Bad Gateway`:** Caddy cannot talk to the backend container.
    * Ensure both containers are on `caddy_net`.
    * Ensure you are using the correct *container name* and *internal port* in the `reverse_proxy` directive.

---

## 7. 🧹 Maintenance

### Updates
To update Caddy to the latest version:
```bash
docker compose pull
docker compose up -d
```

### Backups
Back up the `~/caddy_gateway/data` folder. This contains your SSL certificates. If you lose this, you may hit rate limits when setting up a new server as you'll have to request new certs for all domains at once.