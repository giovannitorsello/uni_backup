#!/bin/bash
set -euo pipefail

DEVICE_CONF_DIR=/etc/bareos/bareos-sd.d/device

log() { echo "[bareos-sd] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa template configurazione
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."
log() { echo "[bareos-dir] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa i template di configurazione con envsubst
#    Le variabili sostituite sono elencate esplicitamente per
#    evitare di toccare eventuali ${...} nel config Bareos stesso
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."
export SD_NAME
export BAREOS_DIRECTOR_PASSWORD BAREOS_SD_PASSWORD
export CHANGER_DEVICE_1 TAPE_AUTOCH1_DEVICE_1 TAPE_AUTOCH1_DEVICE_2 TAPE_AUTOCH1_DEVICE_3 TAPE_AUTOCH1_DEVICE_4
export CHANGER_DEVICE_2 TAPE_AUTOCH2_DEVICE_1 TAPE_AUTOCH2_DEVICE_2 TAPE_AUTOCH2_DEVICE_3 TAPE_AUTOCH2_DEVICE_4

echo "[DEBUG RUNTIME] Verifico variabili d'ambiente:"
echo "DIRECTOR_PASSWORD: $BAREOS_DIRECTOR_PASSWORD"
echo "SD_PASSWORD: $BAREOS_SD_PASSWORD"
echo "SD_NAME: $SD_NAME"


envsubst < /etc/bareos/templates/bareos-sd.conf.tpl > /etc/bareos/bareos-sd.conf
log "Template elaborato."
cp         /etc/bareos/bareos-sd.d/device/autochanger-mhvtl.conf.tpl /etc/bareos/bareos-sd.d/device/active-autochanger.conf.tpl
envsubst < /etc/bareos/bareos-sd.d/device/active-autochanger.conf.tpl > /etc/bareos/bareos-sd.d/device/active-autochanger.conf
log "Template autochanger elaborato."

case "${CHANGER_DEVICE_1:-}" in
  /dev/sg*)
    log "MHVTL MODE: libreria virtuale mhvtl — changer ${CHANGER_DEVICE_1}"
    # Verifica che il changer device sia accessibile prima di procedere
    if [ ! -c "${CHANGER_DEVICE_1}" ]; then
      log "ERRORE: ${CHANGER_DEVICE_1} non trovato — il modulo mhvtl è caricato sull'host?"
      exit 1
    fi
esac

case "${CHANGER_DEVICE_2:-}" in
  /dev/sg*)
    log "MHVTL MODE: libreria virtuale mhvtl — changer ${CHANGER_DEVICE_2}"
    # Verifica che il changer device sia accessibile prima di procedere
    if [ ! -c "${CHANGER_DEVICE_2}" ]; then
      log "ERRORE: ${CHANGER_DEVICE_2} non trovato — il modulo mhvtl è caricato sull'host?"
      exit 1
    fi
esac

log "Configurazione device attiva: $(basename $(readlink -f ${DEVICE_CONF_DIR}/active-autochanger.conf))"

# ---------------------------------------------------------------
# 3. Assicura permessi sulle directory di storage
# ---------------------------------------------------------------
chown bareos:bareos /etc/bareos/bareos-sd.conf

mkdir -p /var/lib/bareos/storage
chown -R bareos:bareos \
  /var/lib/bareos \
  /var/run/bareos \
  /var/log/bareos \
  "${DEVICE_CONF_DIR}/active-autochanger.conf"

# ---------------------------------------------------------------
# 4. Avvia Storage Daemon in foreground
# ---------------------------------------------------------------
log "Avvio bareos-sd (nome: ${SD_NAME:-bareos-sd})..."
exec /usr/sbin/bareos-sd \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-sd.conf