#!/bin/bash
set -euo pipefail

log() { echo "[bareos-sd] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa template configurazione
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."

envsubst '${DIRECTOR_PASSWORD} ${SD_NAME}' \
  < /etc/bareos/templates/bareos-sd.conf.tpl \
  > /etc/bareos/bareos-sd.conf

chown bareos:bareos /etc/bareos/bareos-sd.conf
log "Template elaborato."

# ---------------------------------------------------------------
# 2. Assicura permessi sulle directory di storage
# ---------------------------------------------------------------
mkdir -p /var/lib/bareos/storage
chown -R bareos:bareos /var/lib/bareos /run/bareos /var/log/bareos

# ---------------------------------------------------------------
# 3. Avvia Storage Daemon in foreground
# ---------------------------------------------------------------
log "Avvio bareos-sd (nome: ${SD_NAME:-bareos-sd-01})..."
exec /usr/sbin/bareos-sd \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-sd.conf
