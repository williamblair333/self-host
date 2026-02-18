# Vaultwarden Password Manager — Handoff Document

| **Service**  | Vaultwarden (Self-Hosted Password Manager)    |
| ------------ | --------------------------------------------- |
| **Platform** | Debian GNU/Linux 13 (Trixie) · amd64 · Docker |
| **Status**   | Production                                    |

---

## Quick Reference

| Action      | Command                                                                                      |
| ----------- | -------------------------------------------------------------------------------------------- |
| **Status**  | `cd /opt/docker/vaultwarden && docker compose ps`                                            |
| **Start**   | `cd /opt/docker/vaultwarden && docker compose up -d`                                         |
| **Stop**    | `cd /opt/docker/vaultwarden && docker compose down`                                          |
| **Restart** | `cd /opt/docker/vaultwarden && docker compose restart`                                       |
| **Logs**    | `cd /opt/docker/vaultwarden && docker compose logs -f`                                       |
| **Upgrade** | `cd /opt/docker/vaultwarden && docker compose pull && docker compose up -d --force-recreate` |

---

## Directory Structure

```
/opt/docker/vaultwarden/
├── docker-compose.yaml
├── .env                        # chmod 600
├── data/
│   └── db.sqlite3
├── nginx/
│   └── conf.d/
│       └── vaultwarden.conf
├── certs/                      # Self-signed certs
│   ├── vault.crt
│   └── vault.key
└── certbot/                    # Let's Encrypt certs (if used)
    ├── conf/
    └── www/
```

---

## Initial Setup

### Step 1: Create directories

```bash
sudo mkdir -p /opt/docker/vaultwarden/{data,nginx/conf.d,certs,certbot/{conf,www}}
sudo chown -R $USER:$USER /opt/docker/vaultwarden
cd /opt/docker/vaultwarden
```

### Step 2: Generate admin token

```bash
openssl rand -base64 48
```

Save output for `.env`.

### Step 3: Create `.env`

```bash
vim /opt/docker/vaultwarden/.env
```

```text
DOMAIN=https://vault.yourdomain.local
ADMIN_TOKEN=your-token-from-step-2
SIGNUPS_ALLOWED=true
INVITATIONS_ALLOWED=true
SHOW_PASSWORD_HINT=false
LOG_LEVEL=warn
```

```bash
chmod 600 /opt/docker/vaultwarden/.env
```

### Step 4: Create `docker-compose.yaml`

```bash
vim /opt/docker/vaultwarden/docker-compose.yaml
```

```yaml
name: vaultwarden

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./data:/data
    networks:
      - vaultwarden_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/alive"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  nginx:
    image: nginx:alpine
    container_name: vaultwarden-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certs:/etc/nginx/certs:ro
      - ./certbot/www:/var/www/certbot:ro
    networks:
      - vaultwarden_net
    depends_on:
      - vaultwarden
    command: '/bin/sh -c "while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g ''daemon off;''"'

  certbot:
    image: certbot/certbot
    container_name: vaultwarden-certbot
    restart: unless-stopped
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done'"

networks:
  vaultwarden_net:
    driver: bridge
```

### Step 5: Choose TLS method

- **Option A: Self-signed certificate** — For `.local` domains or internal use
- **Option B: Let's Encrypt** — For public domains with valid DNS

---

## Option A: Self-Signed Certificate

Use this for `.local` domains or when Let's Encrypt isn't possible.

### A1: Generate certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/docker/vaultwarden/certs/vault.key \
    -out /opt/docker/vaultwarden/certs/vault.crt \
    -subj "/CN=vault.yourdomain.local" \
    -addext "subjectAltName=DNS:vault.yourdomain.local"
```

### A2: Create nginx config

```bash
vim /opt/docker/vaultwarden/nginx/conf.d/vaultwarden.conf
```

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name vault.yourdomain.local;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name vault.yourdomain.local;

    ssl_certificate /etc/nginx/certs/vault.crt;
    ssl_certificate_key /etc/nginx/certs/vault.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    client_max_body_size 525M;

    location / {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub/negotiate {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### A3: Add hosts entry (if using .local domain)

```bash
echo "127.0.0.1   vault.yourdomain.local" | sudo tee -a /etc/hosts
```

### A4: Renew self-signed cert (yearly)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/docker/vaultwarden/certs/vault.key \
    -out /opt/docker/vaultwarden/certs/vault.crt \
    -subj "/CN=vault.yourdomain.local" \
    -addext "subjectAltName=DNS:vault.yourdomain.local"
cd /opt/docker/vaultwarden && docker compose restart nginx
```

---

## Option B: Let's Encrypt Certificate

Use this for public domains. Requires:

- Public DNS A record pointing to your server
- Ports 80 and 443 open to the internet

### B1: Create temporary nginx config (HTTP only)

```bash
vim /opt/docker/vaultwarden/nginx/conf.d/vaultwarden.conf
```

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name vault.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'Waiting for HTTPS setup...';
        add_header Content-Type text/plain;
    }
}
```

### B2: Start nginx

```bash
cd /opt/docker/vaultwarden
docker compose up -d nginx
```

### B3: Verify DNS and HTTP

```bash
curl -I http://vault.yourdomain.com
```

### B4: Request certificate

```bash
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    -d vault.yourdomain.com \
    --email admin@yourdomain.com \
    --agree-tos \
    --no-eff-email
```

### B5: Verify certificate obtained

```bash
ls -la /opt/docker/vaultwarden/certbot/conf/live/vault.yourdomain.com/
```

### B6: Update docker-compose.yaml nginx volumes

```bash
vim /opt/docker/vaultwarden/docker-compose.yaml
```

Change nginx volumes to:

```yaml
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
```

### B7: Replace nginx config with HTTPS version

```bash
vim /opt/docker/vaultwarden/nginx/conf.d/vaultwarden.conf
```

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name vault.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name vault.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/vault.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vault.yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    client_max_body_size 525M;

    location / {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub/negotiate {
        proxy_pass http://vaultwarden:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### B8: Certificate renewal

Certbot container auto-renews every 12h. Nginx reloads every 6h to pick up new certs.

Test renewal manually:

```bash
docker compose run --rm certbot renew --dry-run
```

Force renewal:

```bash
docker compose run --rm certbot renew --force-renewal
docker compose exec nginx nginx -s reload
```

Check expiry:

```bash
echo | openssl s_client -servername vault.yourdomain.com \
    -connect vault.yourdomain.com:443 2>/dev/null \
    | openssl x509 -noout -dates
```

---

## Start Services

```bash
cd /opt/docker/vaultwarden
docker compose up -d
```

## Verify

```bash
docker compose ps
```

```bash
curl -kI https://vault.yourdomain.local
```

(Use `-k` flag for self-signed certs only)

---

## Post-Install: Create Account and Lock Down

1. Browse to `https://vault.yourdomain.local`
2. Create your account
3. Disable signups:
   
   ```bash
   sed -i 's/SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/' /opt/docker/vaultwarden/.env
   cd /opt/docker/vaultwarden && docker compose restart vaultwarden
   ```

## Access Admin Panel

```bash
grep ADMIN_TOKEN /opt/docker/vaultwarden/.env
```

Browse to `https://vault.yourdomain.local/admin`

---

## Backup

```bash
cd /opt/docker/vaultwarden
docker compose stop
tar -czf /opt/backups/vaultwarden_$(date +%Y%m%d).tar.gz data/ .env
docker compose start
```

## Restore

```bash
cd /opt/docker/vaultwarden
docker compose down
rm -rf data/
tar -xzf /opt/backups/vaultwarden_YYYYMMDD.tar.gz -C /opt/docker/vaultwarden
docker compose up -d
```

---

## Troubleshooting

| Problem                    | Solution                                                 |
| -------------------------- | -------------------------------------------------------- |
| nginx won't start          | `docker compose logs nginx`                              |
| Config syntax error        | `docker compose exec nginx nginx -t`                     |
| Bad Gateway                | `docker compose logs vaultwarden`                        |
| Can't access admin         | Verify `ADMIN_TOKEN` in `.env`, restart vaultwarden      |
| Cert warning (self-signed) | Expected; accept in browser                              |
| Let's Encrypt fails        | Verify DNS resolves, port 80 open, domain not `.local`   |
| Certbot "no names found"   | Check `server_name` in nginx config matches cert request |

---

## External References

| Resource           | URL                                                       |
| ------------------ | --------------------------------------------------------- |
| Vaultwarden GitHub | https://github.com/dani-garcia/vaultwarden                |
| Vaultwarden Wiki   | https://github.com/dani-garcia/vaultwarden/wiki           |
| Bitwarden Clients  | https://bitwarden.com/download/                           |
| Let's Encrypt      | https://letsencrypt.org/docs/ |
