#!/bin/bash
# ================================================================
# mhvtl-init.sh — Inizializzazione librerie nastro virtuali
#
# Parametri globali (override via .env o variabili shell):
#   MHVTL_DIR          directory dati cartucce  (default: /opt/mhvtl)
#   MHVTL_CONF         directory configurazione (default: /etc/mhvtl)
#   MHVTL_LIBRARIES    numero librerie          (default: 1)
#   MHVTL_TAPE_SIZE_MB dimensione cartuccia MB  (default: 256)
#   MHVTL_BIN          directory binari mhvtl   (default: autodetect)
#
# Parametri per libreria (N = indice libreria, 1-based):
#   MHVTL_LIB<N>_DRIVES  numero drive           (default: MHVTL_DRIVES=2)
#   MHVTL_LIB<N>_SLOTS   numero slot            (default: MHVTL_SLOTS=20)
#   MHVTL_LIB<N>_TAPES   numero cartucce        (default: MHVTL_TAPES=10)
#   MHVTL_LIB<N>_MEDIA   tipo media             (default: MHVTL_MEDIA=LTO8)
#
# Queue numbers (automatici, non modificare):
#   Libreria N  → LIB_Q  = N*10         (10, 20, 30...)
#   Drive  N,i  → DRIVE_Q = LIB_Q+i     (11,12... 21,22...)
#
# Esempio — 2 librerie:
#   MHVTL_LIBRARIES=2
#   MHVTL_LIB1_DRIVES=2  MHVTL_LIB1_SLOTS=20  MHVTL_LIB1_MEDIA=LTO8
#   MHVTL_LIB2_DRIVES=1  MHVTL_LIB2_SLOTS=10  MHVTL_LIB2_MEDIA=LTO5
# ================================================================
set -euo pipefail

# ---------------------------------------------------------------
# Parametri globali con default
# ---------------------------------------------------------------
MHVTL_DIR="${MHVTL_DIR:-/opt/mhvtl}"
MHVTL_CONF="${MHVTL_CONF:-/etc/mhvtl}"
MHVTL_LIBRARIES="${MHVTL_LIBRARIES:-2}"
MHVTL_TAPE_SIZE_MB="${MHVTL_TAPE_SIZE_MB:-256}"

# Default per singola libreria (usati se MHVTL_LIB<N>_* non definiti)
MHVTL_DRIVES="${MHVTL_DRIVES:-4}"
MHVTL_SLOTS="${MHVTL_SLOTS:-43}"
MHVTL_TAPES="${MHVTL_TAPES:-24}"
MHVTL_MEDIA="${MHVTL_MEDIA:-LTO8}"

# ---------------------------------------------------------------
# Autodetect directory binari
# ---------------------------------------------------------------
for BINDIR in "./usr/bin" "/usr/local/bin" "/usr/bin"; do
  if [ -x "${BINDIR}/vtllibrary" ]; then
    MHVTL_BIN="${MHVTL_BIN:-${BINDIR}}"
    break
  fi
done
if [ -z "${MHVTL_BIN:-}" ]; then
  echo "ERRORE: binari mhvtl non trovati. Esegui prima: make (nella dir mhvtl)"
  exit 1
fi

log()  { echo "[mhvtl-init] $(date '+%H:%M:%S') $*"; }
log2() { echo "[mhvtl-init]   $*"; }

log "Configurazione globale:"
log2 "MHVTL_DIR       = ${MHVTL_DIR}"
log2 "MHVTL_CONF      = ${MHVTL_CONF}"
log2 "MHVTL_LIBRARIES = ${MHVTL_LIBRARIES}"
log2 "MHVTL_BIN       = ${MHVTL_BIN}"

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
# 1. Directory globale dati
# ---------------------------------------------------------------
mkdir -p "${MHVTL_DIR}"
mkdir -p "${MHVTL_CONF}"

# ---------------------------------------------------------------
# 2. Genera mhvtl.conf (globale — una sola volta)
#    Sintassi: KEY = VALUE con spazi obbligatori
# ---------------------------------------------------------------
log "Generazione ${MHVTL_CONF}/mhvtl.conf..."
tee "${MHVTL_CONF}/mhvtl.conf" > /dev/null <<EOF
HOME_PATH = ${MHVTL_DIR}
EOF
log "mhvtl.conf generato."

# ---------------------------------------------------------------
# 3. Genera device.conf (tutte le librerie in un unico file)
# ---------------------------------------------------------------
log "Generazione ${MHVTL_CONF}/device.conf..."
tee "${MHVTL_CONF}/device.conf" > /dev/null <<EOF
VERSION: 5
EOF

for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))
  FIRST_DRIVE_Q=$((LIB_Q + 1))

  # Leggi parametri specifici o usa i default globali
  DRIVES=$(eval echo "\${MHVTL_LIB${LIB_IDX}_DRIVES:-${MHVTL_DRIVES}}")
  SLOTS=$(eval  echo "\${MHVTL_LIB${LIB_IDX}_SLOTS:-${MHVTL_SLOTS}}")
  MEDIA=$(eval  echo "\${MHVTL_LIB${LIB_IDX}_MEDIA:-${MHVTL_MEDIA}}")

  log "Libreria ${LIB_IDX}: queue=${LIB_Q} drives=${DRIVES} slots=${SLOTS} media=${MEDIA}"

  tee -a "${MHVTL_CONF}/device.conf" > /dev/null <<EOF

# ── Libreria ${LIB_IDX} (queue ${LIB_Q}) ─────────────────────
Library: ${LIB_Q} CHANNEL: 0 TARGET: $((LIB_IDX * 10)) LUN: 0
  Vendor identification: MHVTL
  Product identification: VTL
  Unit serial number: MHVTL$(printf '%03d' ${LIB_IDX})
  NAA: 10:22:33:44:ab:00:00:$(printf '%02x' ${LIB_IDX})
  Slots: ${SLOTS}
  Drives: ${DRIVES}
EOF

  for i in $(seq 1 ${DRIVES}); do
    DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
    TARGET=$((LIB_IDX * 10 + i))
    tee -a "${MHVTL_CONF}/device.conf" > /dev/null <<EOF

Drive: ${DRIVE_Q} CHANNEL: 0 TARGET: ${TARGET} LUN: 0
  Library ID: ${LIB_Q} Slot: ${i}
  Vendor identification: MHVTL
  Product identification: ULT3580-TD8
  Unit serial number: MHVTLDRV$(printf '%02d' ${LIB_IDX})$(printf '%02d' ${i})
  NAA: 10:22:33:44:ab:$(printf '%02x' ${LIB_IDX}):00:$(printf '%02x' ${i})
  Compression: factor 1 enabled 1
  Compression type: lzo
EOF
  done
done

log "device.conf generato con ${MHVTL_LIBRARIES} librer$([ "${MHVTL_LIBRARIES}" -eq 1 ] && echo 'ia' || echo 'ie')."

# ---------------------------------------------------------------
# 4. Genera library_contents per ogni libreria
#    IMPORTANTE: -D punta a MHVTL_CONF, non MHVTL_DIR
#    vtllibrary cerca library_contents.* in /etc/mhvtl/
# ---------------------------------------------------------------
if [ -x "${MHVTL_BIN}/generate_library_contents" ]; then
  GENLIBCMD="${MHVTL_BIN}/generate_library_contents"
elif [ -x "${MHVTL_BIN}/make_vtl_media" ]; then
  GENLIBCMD="${MHVTL_BIN}/make_vtl_media"
else
  log "ERRORE: nessun tool di generazione library_contents trovato in ${MHVTL_BIN}/"
  exit 1
fi

log "Generazione library_contents con: ${GENLIBCMD}"

for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))
  rm -f "${MHVTL_CONF}/library_contents.${LIB_Q}"
  "${GENLIBCMD}" \
    -C "${MHVTL_CONF}" \
    -D "${MHVTL_CONF}" \
    -f
  if [ ! -f "${MHVTL_CONF}/library_contents.${LIB_Q}" ]; then
    log "ERRORE: library_contents.${LIB_Q} non generato in ${MHVTL_CONF}/"
    exit 1
  fi
  log "  library_contents.${LIB_Q} generato in ${MHVTL_CONF}/"
done


# ---------------------------------------------------------------
# 5. Crea cartucce per ogni libreria
# ---------------------------------------------------------------
for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))

  TAPES=$(eval echo "\${MHVTL_LIB${LIB_IDX}_TAPES:-${MHVTL_TAPES}}")
  MEDIA=$(eval echo "\${MHVTL_LIB${LIB_IDX}_MEDIA:-${MHVTL_MEDIA}}")
  LTO_GEN=$(echo "${MEDIA}" | grep -oP '\d+$')

  mkdir -p "${MHVTL_DIR}/${LIB_Q}"
  log "Libreria ${LIB_IDX} — creazione ${TAPES} cartucce ${MEDIA} in ${MHVTL_DIR}/${LIB_Q}/..."

  for i in $(seq 1 ${TAPES}); do
    BARCODE=$(printf "%02d%04dL%s" ${LIB_IDX} ${i} "${LTO_GEN}")
    if [ -d "${MHVTL_DIR}/${LIB_Q}/${BARCODE}" ]; then
      log2 "${BARCODE} già esistente, saltata."
      continue
    fi
    "${MHVTL_BIN}/mktape" \
      -C "${MHVTL_CONF}" \
      -H "${MHVTL_DIR}/${LIB_Q}" \
      -l ${LIB_Q} \
      -m "${BARCODE}" \
      -t data \
      -d "${MEDIA}" \
      -s "${MHVTL_TAPE_SIZE_MB}" \
    && log2 "Creata ${BARCODE} (${MHVTL_TAPE_SIZE_MB} MB)" \
    || log2 "ERRORE creazione ${BARCODE}"
  done

  # 2 cartucce cleaning per libreria
  for i in $(seq 1 2); do
    BARCODE=$(printf "CL%02d%03dL%s" ${LIB_IDX} ${i} "${LTO_GEN}")
    if [ -d "${MHVTL_DIR}/${LIB_Q}/${BARCODE}" ]; then
      log2 "${BARCODE} già esistente, saltata."
      continue
    fi
    "${MHVTL_BIN}/mktape" \
      -C "${MHVTL_CONF}" \
      -H "${MHVTL_DIR}/${LIB_Q}" \
      -l ${LIB_Q} \
      -m "${BARCODE}" \
      -t clean \
      -d "${MEDIA}" \
      -s 1 \
    && log2 "Creata cleaning tape ${BARCODE}" \
    || log2 "ERRORE creazione ${BARCODE}"
  done
done

# ---------------------------------------------------------------
# 6. Avvia demoni per ogni libreria
# ---------------------------------------------------------------
log "Avvio demoni mhvtl..."
for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))
  FIRST_DRIVE_Q=$((LIB_Q + 1))
  DRIVES=$(eval echo "\${MHVTL_LIB${LIB_IDX}_DRIVES:-${MHVTL_DRIVES}}")

  log "  Avvio vtllibrary libreria ${LIB_IDX} (queue ${LIB_Q})..."
  "${MHVTL_BIN}/vtllibrary" -q ${LIB_Q} &
  sleep 2

  for i in $(seq 1 ${DRIVES}); do
    DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
    log "  Avvio vtltape libreria ${LIB_IDX} drive ${i} (queue ${DRIVE_Q})..."
    "${MHVTL_BIN}/vtltape" -q ${DRIVE_Q} &
    sleep 1
  done
done

sleep 3

# ---------------------------------------------------------------
# 7. Verifica finale
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
log "=== mhvtl pronto: ${MHVTL_LIBRARIES} librer$([ "${MHVTL_LIBRARIES}" -eq 1 ] && echo 'ia' || echo 'ie'), ${TAPES_FOUND} drive ==="

if [ "${CHANGER_FOUND}" -gt 0 ]; then
  CHANGERS=$(lsscsi -g | grep -i mediumx | awk '{print $NF}')
  log "  Robot changer(s): ${CHANGERS}"
else
  log "  Robot changer: non visibile in lsscsi (potrebbe servire riavvio)"
fi

FIRST_NST=$(lsscsi -g | grep -i tape | awk '{print $(NF-1)}' | head -1 | sed 's|/dev/st|/dev/nst|')
FIRST_SG=$(lsscsi -g | grep -i mediumx | awk '{print $NF}' | head -1)

log ""
log "Aggiorna il .env con questi valori:"
log "  CHANGER_DEVICE=${FIRST_SG:-<verifica con: lsscsi -g>}"
log "  TAPE_DEVICE=${FIRST_NST:-<verifica con: lsscsi -g>}"