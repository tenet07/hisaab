#!/bin/bash
# One-time setup on a fresh Ubuntu 22.04/24.04 server (AWS Lightsail Mumbai etc.).
#   cd ~/shopos && sudo bash deploy/server-setup.sh bills.solankielectricals.in
# Installs Docker, writes .env with random passwords, and starts the shop app with HTTPS.
set -euo pipefail
DOMAIN="${1:-}"
[ -z "$DOMAIN" ] && { echo "Usage: sudo bash deploy/server-setup.sh your.domain.in"; exit 1; }
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null; then
  echo "== Installing Docker"
  curl -fsSL https://get.docker.com | sh
fi

if [ ! -f .env ]; then
  echo "== Writing .env (keep this file private; it holds the passwords)"
  umask 077
  cat > .env <<ENV
APP_HOST=$DOMAIN
POSTGRES_PASSWORD=$(openssl rand -hex 24)
SECRET_KEY_BASE=$(openssl rand -hex 64)
SETUP_CODE=$(openssl rand -hex 4)-$(openssl rand -hex 4)
BACKUP_AT=23:30
KEEP_DAYS=30
ENV
else
  echo "== .env already exists, keeping it"
fi
mkdir -p backups && chown 1000:1000 backups

# 2 GB swap so the first build doesn't run out of memory on a small server.
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== Building and starting (first time takes 5-10 minutes)"
docker compose up -d --build
echo
echo "Done. Open https://$DOMAIN on your phone."
echo "First-run setup code: $(grep ^SETUP_CODE .env | cut -d= -f2)"
