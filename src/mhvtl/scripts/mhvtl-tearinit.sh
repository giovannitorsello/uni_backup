#!/bin/bash
# ================================================================
# mhvtl-init.sh — Inizializzazione libreria nastro virtuale
#
# Parametri (override via .env o variabili shell):
#   MHVTL_DIR          directory dati cartucce  (default: /opt/mhvtl)
#   MHVTL_CONF         directory configurazione (default: /etc/mhvtl)
#   MHVTL_DRIVES       numero drive             (default: 2)
#   MHVTL_SLOTS        numero slot cartucce     (default: 20)
#   MHVTL_TAPES        numero cartucce da creare(default: 10)
#   MHVTL_MEDIA        tipo media               (default: LTO8)
#   MHVTL_TAPE_SIZE_MB dimensione cartuccia MB  (default: 1024)
#   MHVTL_BIN          directory binari mhvtl   (default: autodetect)
#
# Queue numbers fissi (standard mhvtl):
#   LIB_Q=10   → robot changer
#   11,12,...  → drive 1, 2, ...
# ================================================================
set -euo pipefail

# ---------------------------------------------------------------
# Parametri con default
# ---------------------------------------------------------------
MHVTL_DIR="${MHVTL_DIR:-/opt/mhvtl}"
MHVTL_CONF="${MHVTL_CONF:-/etc/mhvtl}"
MHVTL_DRIVES="${MHVTL_DRIVES:-2}"
MHVTL_SLOTS="${MHVTL_SLOTS:-20}"
MHVTL_TAPES="${MHVTL_TAPES:-10}"
MHVTL_MEDIA="${MHVTL_MEDIA:-LTO8}"
MHVTL_TAPE_SIZE_MB="${MHVTL_TAPE_SIZE_MB:-1024}"

# Queue numbers — non modificare senza aggiornare anche device.conf
LIB_Q=10
FIRST_DRIVE_Q=11

# ---------------------------------------------------------------
# Autodetect directory binari (build locale o installati)
# ---------------------------------------------------------------
if [ -x "./usr/bin/vtllibrary" ]; then
  MHVTL_BIN="${MHVTL_BIN:-$(pwd)/usr/bin}"
elif [ -x "/usr/local/bin/vtllibrary" ]; then
  MHVTL_BIN="${MHVTL_BIN:-/usr/local/bin}"
elif [ -x "/usr/bin/vtllibrary" ]; then
  MHVTL_BIN="${MHVTL_BIN:-/usr/bin}"
else
  echo "ERRORE: binari mhvtl non trovati. Esegui prima: make (nella dir mhvtl)"
  exit 1
fi

log() { echo "[mhvtl-init] $(date '+%H:%M:%S') $*"; }

log "Configurazione:"
log "  MHVTL_DIR    = ${MHVTL_DIR}"
log "  MHVTL_CONF   = ${MHVTL_CONF}"
log "  MHVTL_DRIVES = ${MHVTL_DRIVES}"
log "  MHVTL_SLOTS  = ${MHVTL_SLOTS}"
log "  MHVTL_TAPES  = ${MHVTL_TAPES}"
log "  MHVTL_MEDIA  = ${MHVTL_MEDIA}"
log "  MHVTL_BIN    = ${MHVTL_BIN}"

# ---------------------------------------------------------------
# 0. Verifica modulo kernel
# ---------------------------------------------------------------
log "Verifica modulo kernel mhvtl..."
if lsmod | grep mhvtl; then
  log "Modulo già caricato — salto insmod."
else
  log "Modulo non caricato — tento insmod..."
  KOPATH=$(find . /lib/modules/$(uname -r) -name "mhvtl.ko" 2>/dev/null | head -1)
  if [ -z "${KOPATH}" ]; then
    log "ERRORE: mhvtl.ko non trovato. Compila prima il modulo:"
    log "  cd kernel && make && sudo insmod mhvtl.ko"
    exit 1
  fi
  insmod "${KOPATH}"
  log "Modulo caricato da ${KOPATH}"
fi
log "Modulo kernel OK."

# ---------------------------------------------------------------
# 0b. Crea /dev/mhvtl se non esiste
# ---------------------------------------------------------------
log "Verifica device node /dev/mhvtl..."
if [ ! -c /dev/mhvtl ]; then
  MAJOR=$(awk '/mhvtl/{print $1}' /proc/devices)
  if [ -z "${MAJOR}" ]; then
    log "ERRORE: mhvtl non in /proc/devices — modulo non caricato?"
    exit 1
  fi
  log "Creazione /dev/mhvtl (major ${MAJOR})..."
  mknod /dev/mhvtl c "${MAJOR}" 0
  chmod 666 /dev/mhvtl
  log "/dev/mhvtl creato."
else
  log "/dev/mhvtl già presente."
fi

# ---------------------------------------------------------------
# 1. Crea directory
#    Le cartucce vivono in ${MHVTL_DIR}/${LIB_Q}/ — sottodirectory
#    per library ID, come richiesto da mhvtl internamente
# ---------------------------------------------------------------
log "Creazione directory ${MHVTL_DIR}/${LIB_Q} e ${MHVTL_CONF}..."
mkdir -p "${MHVTL_DIR}/${LIB_Q}"
mkdir -p "${MHVTL_CONF}"

# ---------------------------------------------------------------
# 2. Genera mhvtl.conf
#    IMPORTANTE: sintassi con ' = ' (spazi intorno a =), NON ':'
# ---------------------------------------------------------------
log "Generazione ${MHVTL_CONF}/mhvtl.conf..."
tee "${MHVTL_CONF}/mhvtl.conf" > /dev/null <<EOF
HOME_PATH = ${MHVTL_DIR}
EOF
log "mhvtl.conf generato."

# ---------------------------------------------------------------
# 3. Genera device.conf
# ---------------------------------------------------------------
log "Generazione ${MHVTL_CONF}/device.conf..."
tee "${MHVTL_CONF}/device.conf" > /dev/null <<EOF
VERSION: 5

# ── Robot changer (queue ${LIB_Q}) ───────────────────────────
Library: ${LIB_Q} CHANNEL: 0 TARGET: 0 LUN: 0
  Vendor identification: MHVTL
  Product identification: VTL
  Unit serial number: MHVTL001
  NAA: 10:22:33:44:ab:00:00:01
  Slots: ${MHVTL_SLOTS}
  Drives: ${MHVTL_DRIVES}
EOF

for i in $(seq 1 ${MHVTL_DRIVES}); do
  DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
  tee -a "${MHVTL_CONF}/device.conf" > /dev/null <<EOF

Drive: ${DRIVE_Q} CHANNEL: 0 TARGET: ${i} LUN: 0
  Library ID: ${LIB_Q} Slot: ${i}
  Vendor identification: MHVTL
  Product identification: ULT3580-TD8
  Unit serial number: MHVTLDRV$(printf '%03d' ${i})
  NAA: 10:22:33:44:ab:01:00:$(printf '%02x' ${i})
  Compression: factor 1 enabled 1
  Compression type: lzo
EOF
done

log "device.conf generato: Library=${LIB_Q}, Drive=${FIRST_DRIVE_Q}..$((FIRST_DRIVE_Q + MHVTL_DRIVES - 1))"

# ---------------------------------------------------------------
# 4. Genera library_contents.${LIB_Q}
# ---------------------------------------------------------------
log "Generazione library_contents.${LIB_Q}..."

# Il tool si chiama generate_library_contents nelle versioni recenti
if [ -x "${MHVTL_BIN}/generate_library_contents" ]; then
  GENLIBCMD="${MHVTL_BIN}/generate_library_contents"
elif [ -x "${MHVTL_BIN}/make_vtl_media" ]; then
  GENLIBCMD="${MHVTL_BIN}/make_vtl_media"
else
  log "ERRORE: nessun tool di generazione library_contents trovato."
  log "  Cercati: generate_library_contents, make_vtl_media"
  log "  In: ${MHVTL_BIN}/"
  exit 1
fi

log "Uso tool: ${GENLIBCMD}"
# Rimuovi il file esistente prima di rigenerare
rm -f "${MHVTL_DIR}/library_contents.${LIB_Q}"

"${GENLIBCMD}" \
  -C "${MHVTL_CONF}" \
  -D "${MHVTL_DIR}" \
  -f

# Verifica nella directory corretta
if [ ! -f "${MHVTL_DIR}/library_contents.${LIB_Q}" ]; then
  log "ERRORE: library_contents.${LIB_Q} non generato in ${MHVTL_DIR}/"
  exit 1
fi
log "library_contents.${LIB_Q} generato in ${MHVTL_DIR}/"


# ---------------------------------------------------------------
# 5. Crea le cartucce virtuali
#    Formato barcode LTO standard: NNNNNNLT
#      NNNNNN = 6 cifre sequenziali
#      L      = prefisso tipo LTO
#      T      = numero generazione (8=LTO8, 7=LTO7...)
#    Le cartucce vanno in ${MHVTL_DIR}/${LIB_Q}/
# ---------------------------------------------------------------
LTO_GEN=$(echo "${MHVTL_MEDIA}" | grep -oP '\d+$')
log "Creazione ${MHVTL_TAPES} cartucce ${MHVTL_MEDIA} in ${MHVTL_DIR}/${LIB_Q}/..."

for i in $(seq 1 ${MHVTL_TAPES}); do
  BARCODE=$(printf "%06dL%s" ${i} "${LTO_GEN}")
  if [ -d "${MHVTL_DIR}/${LIB_Q}/${BARCODE}" ]; then
    log "  ${BARCODE} già esistente, saltata."
    continue
  fi
  "${MHVTL_BIN}/mktape" \
    -C "${MHVTL_CONF}" \
    -H "${MHVTL_DIR}/${LIB_Q}" \
    -l ${LIB_Q} \
    -m "${BARCODE}" \
    -t data \
    -d "${MHVTL_MEDIA}" \
    -s "${MHVTL_TAPE_SIZE_MB}" \
  && log "  Creata ${BARCODE} (${MHVTL_TAPE_SIZE_MB} MB)" \
  || log "  ERRORE creazione ${BARCODE}"
done

# Cartucce cleaning — 2 per default
log "Creazione cartucce cleaning..."
for i in $(seq 1 2); do
  BARCODE=$(printf "CLN%03dL%s" ${i} "${LTO_GEN}")
  if [ -d "${MHVTL_DIR}/${LIB_Q}/${BARCODE}" ]; then
    log "  ${BARCODE} già esistente, saltata."
    continue
  fi
  "${MHVTL_BIN}/mktape" \
    -C "${MHVTL_CONF}" \
    -H "${MHVTL_DIR}/${LIB_Q}" \
    -l ${LIB_Q} \
    -m "${BARCODE}" \
    -t clean \
    -d "${MHVTL_MEDIA}" \
    -s 1 \
  && log "  Creata cleaning tape ${BARCODE}" \
  || log "  ERRORE creazione ${BARCODE}"
done

# ---------------------------------------------------------------
# 6. Avvia demoni
# ---------------------------------------------------------------
log "Avvio vtllibrary (queue ${LIB_Q})..."
"${MHVTL_BIN}/vtllibrary" -q ${LIB_Q} &
sleep 2

for i in $(seq 1 ${MHVTL_DRIVES}); do
  DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
  log "Avvio vtltape drive ${i} (queue ${DRIVE_Q})..."
  "${MHVTL_BIN}/vtltape" -q ${DRIVE_Q} &
  sleep 1
done

sleep 2

# ---------------------------------------------------------------
# 7. Verifica finale
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# 6. Verifica finale
# ---------------------------------------------------------------
log "Verifica device creati..."

TAPES_FOUND=$(lsscsi -g | grep -i mhvtl | grep -i tape | wc -l)
CHANGER_FOUND=$(lsscsi -g | grep -i mhvtl | grep -i mediumx | wc -l)

if [ "${TAPES_FOUND}" -eq 0 ]; then
  log "ERRORE: nessun drive mhvtl visibile dopo l'avvio."
  log "  journalctl -n 50 | grep -i vtl"
  exit 1
fi

lsscsi -g | grep -i mhvtl || true

log ""
log "=== mhvtl pronto ==="

if [ "${CHANGER_FOUND}" -gt 0 ]; then
  CHANGER=$(lsscsi -g | grep -i mediumx | awk '{print $NF}' | head -1)
  log "  Robot changer : ${CHANGER}"
else
  log "  Robot changer : non visibile in lsscsi (potrebbe servire riavvio)"
fi

