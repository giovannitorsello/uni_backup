#!/bin/bash
set -euo pipefail

log() { echo "[bareos-fd] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa template configurazione
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."

envsubst '${DIRECTOR_PASSWORD} ${FD_NAME}' \
  < /etc/bareos/templates/bareos-fd.conf.tpl \
  > /etc/bareos/bareos-fd.conf

chown bareos:bareos /etc/bareos/bareos-fd.conf
log "Template elaborato."

# ---------------------------------------------------------------
# 2. Permessi directory
# ---------------------------------------------------------------
mkdir -p /var/lib/bareos
chown -R bareos:bareos /var/lib/bareos /run/bareos /var/log/bareos

# ---------------------------------------------------------------
# 3. Avvia File Daemon in foreground
# ---------------------------------------------------------------
log "Avvio bareos-fd (nome: ${FD_NAME:-bareos-fd})..."
exec /usr/sbin/bareos-fd \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-fd.conf
