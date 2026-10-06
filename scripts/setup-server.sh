#!/usr/bin/env bash
# scripts/setup-server.sh
# Idempotent provisioning script for quickballot-dev VM.
# Safe to run multiple times — already-installed tools are skipped.
set -euo pipefail

echo "==> Updating package index"
apt-get update -qq

# ── Swap file (2 GB) ────────────────────────────────────────────────────────
if [ ! -f /swapfile ]; then
  echo "==> Creating 2 GB swap file"
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
else
  echo "==> Swap file already exists, skipping"
fi

# ── Core utilities ───────────────────────────────────────────────────────────
echo "==> Installing core utilities"
apt-get install -y -qq \
  curl \
  git \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common

# ── Docker CE ────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "==> Installing Docker CE"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  systemctl enable --now docker
else
  echo "==> Docker already installed, skipping"
fi

# Add the invoking user to the docker group (requires logout/login to take effect)
SUDO_USER="${SUDO_USER:-}"
if [ -n "$SUDO_USER" ]; then
  usermod -aG docker "$SUDO_USER"
  echo "==> Added $SUDO_USER to docker group (log out and back in to activate)"
fi

# ── Node.js 20 (NodeSource) ──────────────────────────────────────────────────
if ! command -v node &>/dev/null || [[ "$(node --version)" != v20* ]]; then
  echo "==> Installing Node.js 20"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
else
  echo "==> Node.js 20 already installed, skipping"
fi

# ── Python 3 + pip ───────────────────────────────────────────────────────────
echo "==> Installing Python 3 and pip"
apt-get install -y -qq python3 python3-pip python3-venv

# ── nginx ────────────────────────────────────────────────────────────────────
if ! command -v nginx &>/dev/null; then
  echo "==> Installing nginx"
  apt-get install -y -qq nginx
  systemctl enable nginx
else
  echo "==> nginx already installed, skipping"
fi

# ── fail2ban ─────────────────────────────────────────────────────────────────
if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
  echo "==> Installing fail2ban"
  apt-get install -y -qq fail2ban
  systemctl enable --now fail2ban
else
  echo "==> fail2ban already running, skipping"
fi

# ── UFW firewall ─────────────────────────────────────────────────────────────
echo "==> Configuring UFW"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo ""
echo "==> Provisioning complete."
echo "    If this was the first run, log out and back in so docker group membership takes effect."
echo "    Verify with: docker run hello-world"