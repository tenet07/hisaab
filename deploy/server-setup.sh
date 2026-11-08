#!/bin/bash
# One-time setup on a fresh Ubuntu 22.04/24.04 server with 1 GB RAM or more.
#   cd ~/shopos && sudo bash deploy/server-setup.sh bills.yourshop.in
# Installs Docker, writes .env with random secrets, and starts the shop app with HTTPS.
set -euo pipefail
DOMAIN="${1:-}"
[ -z "$DOMAIN" ] && { echo "Usage: sudo bash deploy/server-setup.sh your.domain.in"; exit 1; }
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null; then
  echo "== Installing Docker"
  curl -fsSL https://get.docker.com | sh
fi

if [ ! -f .env ]; then
  echo "== Writing .env (keep this file private; it holds the secrets)"
  umask 077
  sed -e "s|^APP_HOST=.*|APP_HOST=$DOMAIN|" \
      -e "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$(openssl rand -hex 64)|" \
      -e "s|^SETUP_CODE=.*|SETUP_CODE=$(openssl rand -hex 4)-$(openssl rand -hex 4)|" \
      .env.example > .env
else
  echo "== .env already exists, keeping it"
fi
mkdir -p backups && chown 1000:1000 backups   # written by the backup container (user 1000)

# 1 GB swap: headroom on a 1 GB server (and needed if the app is ever built here).
if ! swapon --show | grep -q .; then
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== Downloading and starting"
docker compose pull app || { echo "(no ready-made image; building here, ~10 minutes)"; docker compose build app; }
docker compose up -d --build
echo
echo "Done. Open https://$DOMAIN on your phone."
echo "First-run setup code: $(grep ^SETUP_CODE .env | cut -d= -f2)"
echo "Next: turn on the off-server copy to Cloudflare R2 (DEPLOY.md step 3)."
