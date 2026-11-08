#!/bin/sh
# Nightly database backup. Every bill, payment, stock entry and delivery photo is in it.
#   sh backup.sh now    one backup immediately
#   sh backup.sh loop   (default in compose) one backup every night at $BACKUP_AT
set -eu
backup_now() {
  f="${BACKUP_DIR:-/backups}/shopos-$(date +%Y-%m-%d_%H%M).dump"
  pg_dump --format=custom --no-owner --file="$f.part" && mv "$f.part" "$f"
  # A backup you can't restore is not a backup: check the file lists cleanly.
  pg_restore --list "$f" > /dev/null
  find "${BACKUP_DIR:-/backups}" -name 'shopos-*.dump' -mtime +"${KEEP_DAYS:-30}" -delete
  echo "$(date '+%F %T') backup ok: $f ($(du -h "$f" | cut -f1))"
}
if [ "${1:-loop}" = "now" ]; then backup_now; exit 0; fi
echo "Backups every night at ${BACKUP_AT}, kept ${KEEP_DAYS} days"
while true; do
  # Seconds until the next BACKUP_AT (HH:MM), with plain arithmetic so it works on any date tool.
  h=${BACKUP_AT%:*}; m=${BACKUP_AT#*:}
  now=$(( $(date +%-H) * 3600 + $(date +%-M) * 60 + $(date +%-S) ))
  target=$(( ${h#0} * 3600 + ${m#0} * 60 ))
  [ "$target" -le "$now" ] && target=$((target + 86400))
  sleep $((target - now))
  backup_now || echo "$(date '+%F %T') BACKUP FAILED"
done
