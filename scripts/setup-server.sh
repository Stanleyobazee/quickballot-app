#!/usr/bin/env bash
#
# QuickBallot - Phase 1 server bootstrap
# Idempotent: safe to run multiple times on the same Ubuntu host.
# Installs: Docker, Nginx, fail2ban, a swap file, and baseline hardening.
#
# Usage: sudo ./setup-server.sh

set -euo pipefail

SWAP_FILE="/swapfile"
SWAP_SIZE_GB="2"

log() { echo -e "\n[setup] $*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo: sudo $0" >&2
  exit 1
fi

log "Updating package index"
apt-get update -y

log "Installing base packages (curl, ufw, fail2ban, nginx, unattended-upgrades)"
apt-get install -y \
  ca-certificates curl gnupg lsb-release \
  ufw fail2ban nginx unattended-upgrades

# --- Docker (official repo, idempotent) -------------------------------------
if ! command -v docker &>/dev/null; then
  log "Installing Docker Engine"
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  ARCH="$(dpkg --print-architecture)"
  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker already installed, skipping"
fi

# Let the invoking sudo user run docker without sudo (if not already a member)
TARGET_USER="${SUDO_USER:-}"
if [[ -n "$TARGET_USER" ]] && ! id -nG "$TARGET_USER" | grep -qw docker; then
  log "Adding $TARGET_USER to the docker group (re-login required to take effect)"
  usermod -aG docker "$TARGET_USER"
fi

systemctl enable --now docker

# --- Swap file ---------------------------------------------------------------
if [[ -f "$SWAP_FILE" ]]; then
  log "Swap file already exists, skipping"
else
  log "Creating ${SWAP_SIZE_GB}G swap file"
  fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE"
  chmod 600 "$SWAP_FILE"
  mkswap "$SWAP_FILE"
  swapon "$SWAP_FILE"
fi

if ! grep -q "^${SWAP_FILE} " /etc/fstab; then
  log "Persisting swap file in /etc/fstab"
  echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
fi

# --- fail2ban ------------------------------------------------------------
if [[ ! -f /etc/fail2ban/jail.local ]]; then
  log "Writing fail2ban jail.local (sshd protection)"
  cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port    = ssh
maxretry = 5
bantime  = 1h
findtime = 10m
EOF
fi
systemctl enable --now fail2ban
systemctl restart fail2ban

# --- Nginx -----------------------------------------------------------------
systemctl enable --now nginx

# --- UFW ---------------------------------------------------------------------
log "Configuring UFW (deny incoming by default, allow SSH/HTTP/HTTPS only)"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

log "Done. Versions:"
docker --version
nginx -v
fail2ban-client --version | head -1
ufw status verbose
