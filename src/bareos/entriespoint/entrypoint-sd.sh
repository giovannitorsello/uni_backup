#!/bin/bash
set -euo pipefail

DEVICE_CONF_DIR=/etc/bareos/bareos-sd.d/device

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
# 2. Selezione device / autochanger in base all'ambiente
#
#    TAPE_DEVICE non impostato  → file-based (sviluppo, CI)
#    TAPE_DEVICE=/dev/sg*       → mhvtl     (test libreria virtuale)
#    TAPE_DEVICE=/dev/nst*      → hardware  (produzione)
# ---------------------------------------------------------------
case "${TAPE_DEVICE:-}" in

  "")
    log "DEV MODE: nessun device fisico — autochanger file-based"
    # Crea le directory che simulano gli slot della libreria
    for slot in slot0 slot1 slot2 slot3; do
      mkdir -p /var/lib/bareos/storage/${slot}
    done
    cp "${DEVICE_CONF_DIR}/autochanger-dev.conf" \
       "${DEVICE_CONF_DIR}/active-autochanger.conf"
    ;;

  /dev/sg*)
    log "MHVTL MODE: libreria virtuale mhvtl — changer ${TAPE_DEVICE}"
    # Verifica che il changer device sia accessibile prima di procedere
    if [ ! -c "${TAPE_DEVICE}" ]; then
      log "ERRORE: ${TAPE_DEVICE} non trovato — il modulo mhvtl è caricato sull'host?"
      exit 1
    fi
    cp "${DEVICE_CONF_DIR}/autochanger-mhvtl.conf" \
       "${DEVICE_CONF_DIR}/active-autochanger.conf"
    ;;

  /dev/nst*)
    log "PROD MODE: hardware reale — drive ${TAPE_DEVICE}"
    # Verifica che il device nastro sia accessibile
    if [ ! -c "${TAPE_DEVICE}" ]; then
      log "ERRORE: ${TAPE_DEVICE} non trovato — il drive è acceso e collegato?"
      exit 1
    fi
    cp "${DEVICE_CONF_DIR}/autochanger-prod.conf" \
       "${DEVICE_CONF_DIR}/active-autochanger.conf"
    ;;

  *)
    log "ERRORE: TAPE_DEVICE='${TAPE_DEVICE}' non riconosciuto."
    log "        Valori attesi: vuoto | /dev/sg<N> | /dev/nst<N>"
    exit 1
    ;;

esac

log "Configurazione device attiva: $(basename $(readlink -f ${DEVICE_CONF_DIR}/active-autochanger.conf))"

# ---------------------------------------------------------------
# 3. Assicura permessi sulle directory di storage
# ---------------------------------------------------------------
mkdir -p /var/lib/bareos/storage
chown -R bareos:bareos \
  /var/lib/bareos \
  /run/bareos \
  /var/log/bareos \
  "${DEVICE_CONF_DIR}/active-autochanger.conf"

# ---------------------------------------------------------------
# 4. Avvia Storage Daemon in foreground
# ---------------------------------------------------------------
log "Avvio bareos-sd (nome: ${SD_NAME:-bareos-sd-01})..."
exec /usr/sbin/bareos-sd \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-sd.conf