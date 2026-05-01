#!/bin/bash
set -euo pipefail

log() { echo "[mhvtl] $(date '+%H:%M:%S') $*"; }

# Carica il modulo kernel sull'host
log "Caricamento modulo kernel mhvtl..."
if ! lsmod | grep -q mhvtl; then
  modprobe mhvtl || {
    log "ERRORE: impossibile caricare mhvtl."
    log "Esegui sull'host: sudo apt install mhvtl-dkms"
    exit 1
  }
fi

log "Modulo caricato. Avvio demone mhvtl..."
exec /usr/local/sbin/mhvtl_d