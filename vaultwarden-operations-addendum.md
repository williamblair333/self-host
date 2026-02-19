# Vaultwarden Operations Addendum

> **Companion to:** `vaultwarden-installer.md`  
> **Assumes:** Vaultwarden already deployed per main handoff document

---

## 1. Organization & Collection Structure

Vaultwarden Organizations provide shared access and logical grouping. This structure separates human logins from infrastructure secrets.

### 1.1 Create the Organization

1. Log into Vaultwarden web vault
2. **Settings → Organizations → New Organization**
3. Name: `Infrastructure` (or your preference)
4. Add yourself as Owner

### 1.2 Create Collections

Within the `Infrastructure` organization, create these collections:

| Collection | Contents |
|------------|----------|
| `Network Devices` | Router/switch credentials, console passwords, SNMP strings |
| `Cloud Providers` | Azure/AWS/GCP portal logins (not API keys—those go in Infisical later) |
| `Docker Stacks` | Secure Notes containing `.env` contents per stack |
| `Certificates & Keys` | Secure Notes with cert material, private keys, expiry dates |
| `Service Accounts` | Shared accounts for services (SMTP, DNS providers, registrars) |

### 1.3 Secure Note Format for `.env` Files

For each Docker stack, create a Secure Note:
```
Name: vaultwarden .env
Collection: Docker Stacks
---
# vaultwarden/.env
# Last updated: 2025-02-19
# Location: /opt/docker/vaultwarden/.env

DOMAIN=https://vault.yourdomain.local
ADMIN_TOKEN=<redacted-store-actual-value-here>
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=true
SHOW_PASSWORD_HINT=false
LOG_LEVEL=warn
```

### 1.4 Assign Successor Access

1. **Organization → Manage → People → Invite User**
2. Assign `Owner` role for full succession rights
3. Document this in Break Glass kit

---

## 2. Automated Backup Script

### 2.1 Create backup script
```bash
sudo mkdir -p /opt/scripts /opt/backups/vaultwarden
sudo vim /opt/scripts/vaultwarden-backup.sh
```
```bash
#!/bin/bash
set -euo pipefail

# Configuration
COMPOSE_DIR="/opt/docker/vaultwarden"
BACKUP_DIR="/opt/backups/vaultwarden"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/vaultwarden_${DATE}.tar.gz"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Stop services for consistent backup
cd "${COMPOSE_DIR}"
docker compose stop

# Create encrypted backup
tar -czf "${BACKUP_FILE}" \
    -C "${COMPOSE_DIR}" \
    data/ \
    .env \
    docker-compose.yaml \
    nginx/ \
    certs/

# Restart services
docker compose start

# Set permissions
chmod 600 "${BACKUP_FILE}"

# Cleanup old backups
find "${BACKUP_DIR}" -name "vaultwarden_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

# Log result
echo "[$(date)] Backup completed: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
```
```bash
sudo chmod 700 /opt/scripts/vaultwarden-backup.sh
```

### 2.2 Schedule daily backup
```bash
sudo crontab -e
```

Add:
```
0 3 * * * /opt/scripts/vaultwarden-backup.sh >> /var/log/vaultwarden-backup.log 2>&1
```

### 2.3 Manual backup
```bash
sudo /opt/scripts/vaultwarden-backup.sh
```

### 2.4 Verify backups
```bash
ls -lh /opt/backups/vaultwarden/
tar -tzf /opt/backups/vaultwarden/vaultwarden_YYYYMMDD-HHMMSS.tar.gz | head -20
```

---

## 3. Break Glass Recovery Kit

**Purpose:** Offline document enabling full recovery by a successor with zero prior access.

### 3.1 Create the document

Print this and store in a secure physical location (safe, safety deposit box).
```
╔══════════════════════════════════════════════════════════════════╗
║                    BREAK GLASS RECOVERY KIT                      ║
║                         Vaultwarden                              ║
╠══════════════════════════════════════════════════════════════════╣
║ Last Updated: ____________    Prepared By: _______________       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ SERVER ACCESS                                                    ║
║ ─────────────────────────────────────────────────────────────    ║
║ Hostname/IP:     _________________________________________       ║
║ SSH User:        _________________________________________       ║
║ SSH Port:        _________________________________________       ║
║ SSH Key Location: ________________________________________       ║
║ (or password):   _________________________________________       ║
║                                                                  ║
║ VAULTWARDEN ADMIN                                                ║
║ ─────────────────────────────────────────────────────────────    ║
║ Web URL:         https://________________________________        ║
║ Admin Panel:     https://________________________________/admin  ║
║ Admin Token:     _________________________________________       ║
║                  _________________________________________       ║
║                                                                  ║
║ MASTER ACCOUNT (if no org access)                                ║
║ ─────────────────────────────────────────────────────────────    ║
║ Email:           _________________________________________       ║
║ Master Password: _________________________________________       ║
║                  _________________________________________       ║
║                                                                  ║
║ BACKUP LOCATIONS                                                 ║
║ ─────────────────────────────────────────────────────────────    ║
║ Local:           /opt/backups/vaultwarden/                       ║
║ Offsite:         _________________________________________       ║
║ Encryption Key:  _________________________________________       ║
║                                                                  ║
║ RECOVERY STEPS                                                   ║
║ ─────────────────────────────────────────────────────────────    ║
║ 1. SSH to server using credentials above                         ║
║ 2. cd /opt/docker/vaultwarden                                    ║
║ 3. docker compose ps  (verify status)                            ║
║ 4. If rebuild needed:                                            ║
║    - Restore backup: see HANDOFF.md "Restore" section            ║
║    - docker compose up -d                                        ║
║ 5. Access admin panel to manage users                            ║
║                                                                  ║
║ EMERGENCY CONTACTS                                               ║
║ ─────────────────────────────────────────────────────────────    ║
║ Primary:         _________________________________________       ║
║ Secondary:       _________________________________________       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 3.2 Verification schedule

Add to calendar:
- **Quarterly:** Verify admin token still works
- **Semi-annually:** Test restore from backup to a VM
- **Annually:** Update Break Glass document, rotate admin token

### 3.3 Token rotation procedure
```bash
# Generate new token
openssl rand -base64 48

# Update .env
vim /opt/docker/vaultwarden/.env

# Restart
cd /opt/docker/vaultwarden && docker compose restart vaultwarden

# UPDATE BREAK GLASS DOCUMENT IMMEDIATELY
```

---

## 4. Future: Infisical Integration

When ready to add machine secrets management:

1. Deploy Infisical stack (requires PostgreSQL + Redis)
2. Migrate from Vaultwarden Secure Notes:
   - `Docker Stacks` collection → Infisical projects
   - `Certificates & Keys` → Infisical with expiry alerts
3. Keep in Vaultwarden:
   - Human logins (Cloud Providers, Service Accounts)
   - Network device credentials
   - Break Glass recovery codes

Trigger to implement: When you have 5+ services needing runtime secret injection, or when standing up CI/CD.

---

## References

| Resource | Location |
|----------|----------|
| Main Handoff | `vaultwarden-installer.md` |
| Vaultwarden Wiki | https://github.com/dani-garcia/vaultwarden/wiki |
| Bitwarden CLI | https://bitwarden.com/help/cli/ |
| Infisical Docs | https://infisical.com/docs |