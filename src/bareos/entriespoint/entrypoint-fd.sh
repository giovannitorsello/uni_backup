#!/bin/bash
set -euo pipefail

log() { echo "[bareos-fd] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa template configurazione
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."
export FD_NAME
export BAREOS_DIRECTOR_PASSWORD BAREOS_SD_PASSWORD

echo "[DEBUG RUNTIME] Verifico variabili d'ambiente:"
echo "DIRECTOR_PASSWORD: $BAREOS_DIRECTOR_PASSWORD"
echo "FD_NAME: $FD_NAME"


envsubst < /etc/bareos/templates/bareos-fd.conf.tpl > /etc/bareos/bareos-fd.conf
log "Template elaborato."

# ---------------------------------------------------------------
# 2. Permessi directory
# ---------------------------------------------------------------
mkdir -p /var/lib/bareos
chown -R bareos:bareos /var/lib/bareos /var/run/bareos /var/log/bareos

# ---------------------------------------------------------------
# 3. Avvia File Daemon in foreground
# ---------------------------------------------------------------
log "Avvio bareos-fd (nome: ${FD_NAME:-bareos-fd})..."
chown bareos:bareos /etc/bareos/bareos-fd.conf
exec /usr/sbin/bareos-fd \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-fd.conf
