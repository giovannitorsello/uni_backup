#!/bin/bash
# ================================================================
# mhvtl-teardown.sh — Arresto e pulizia librerie nastro virtuali
#
# Parametri (override via .env o variabili shell):
#   MHVTL_DIR       directory dati cartucce  (default: /opt/mhvtl)
#   MHVTL_CONF      directory configurazione (default: /etc/mhvtl)
#   MHVTL_LIBRARIES numero librerie          (default: 1)
#   MHVTL_DRIVES    drive per libreria       (default: 2)
#   MHVTL_CLEAN     rimuove dati e conf      (default: no)
#                     "yes" → reset completo
#                     "no"  → arresta demoni, conserva dati
#
# Utilizzo:
#   sudo bash mhvtl-teardown.sh                    # arresta, conserva
#   sudo MHVTL_CLEAN=yes bash mhvtl-teardown.sh   # reset completo
# ================================================================
set -euo pipefail

MHVTL_DIR="${MHVTL_DIR:-/opt/mhvtl}"
MHVTL_CONF="${MHVTL_CONF:-/etc/mhvtl}"
MHVTL_LIBRARIES="${MHVTL_LIBRARIES:-1}"
MHVTL_DRIVES="${MHVTL_DRIVES:-2}"
MHVTL_CLEAN="${MHVTL_CLEAN:-no}"

log()  { echo "[mhvtl-stop] $(date '+%H:%M:%S') $*"; }
log2() { echo "[mhvtl-stop]   $*"; }
warn() { echo "[mhvtl-stop] $(date '+%H:%M:%S') WARN: $*"; }

log "Configurazione:"
log2 "MHVTL_DIR       = ${MHVTL_DIR}"
log2 "MHVTL_CONF      = ${MHVTL_CONF}"
log2 "MHVTL_LIBRARIES = ${MHVTL_LIBRARIES}"
log2 "MHVTL_DRIVES    = ${MHVTL_DRIVES}"
log2 "MHVTL_CLEAN     = ${MHVTL_CLEAN}"

# ---------------------------------------------------------------
# Funzione: termina un processo per pattern con graceful + kill -9
# ---------------------------------------------------------------
kill_proc() {
  local PATTERN="$1"
  local LABEL="$2"

  PIDS=$(pgrep -f "${PATTERN}" 2>/dev/null || true)
  if [ -z "${PIDS}" ]; then
    log2 "${LABEL} non in esecuzione."
    return
  fi

  log2 "Termino ${LABEL} (PID: ${PIDS})..."
  kill ${PIDS} 2>/dev/null || true

  # Attendi graceful shutdown max 5s
  for _ in $(seq 1 5); do
    pgrep -f "${PATTERN}" &>/dev/null || break
    sleep 1
  done

  # Forza kill se ancora in esecuzione
  PIDS=$(pgrep -f "${PATTERN}" 2>/dev/null || true)
  if [ -n "${PIDS}" ]; then
    warn "${LABEL} non risponde — kill -9..."
    kill -9 ${PIDS} 2>/dev/null || true
  fi
  log2 "${LABEL} terminato."
}

# ---------------------------------------------------------------
# 1. Termina vtltape per ogni drive di ogni libreria
# ---------------------------------------------------------------
log "Arresto vtltape (${MHVTL_LIBRARIES} librer$([ "${MHVTL_LIBRARIES}" -eq 1 ] && echo 'ia' || echo 'ie'))..."

for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))
  FIRST_DRIVE_Q=$((LIB_Q + 1))
  DRIVES=$(eval echo "\${MHVTL_LIB${LIB_IDX}_DRIVES:-${MHVTL_DRIVES}}")

  for i in $(seq 1 ${DRIVES}); do
    DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
    kill_proc "vtltape -q ${DRIVE_Q}" "vtltape lib${LIB_IDX} drive${i} (queue ${DRIVE_Q})"
  done
done

# ---------------------------------------------------------------
# 2. Termina vtllibrary per ogni libreria
# ---------------------------------------------------------------
log "Arresto vtllibrary (${MHVTL_LIBRARIES} librer$([ "${MHVTL_LIBRARIES}" -eq 1 ] && echo 'ia' || echo 'ie'))..."

for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
  LIB_Q=$((LIB_IDX * 10))
  kill_proc "vtllibrary -q ${LIB_Q}" "vtllibrary lib${LIB_IDX} (queue ${LIB_Q})"
done

# Verifica orfani vtl non intercettati dal loop
ORPHANS=$(pgrep -f "vtl(library|tape)" 2>/dev/null || true)
if [ -n "${ORPHANS}" ]; then
  warn "Processi vtl orfani (PID: ${ORPHANS}) — kill -9..."
  kill -9 ${ORPHANS} 2>/dev/null || true
fi

# ---------------------------------------------------------------
# 2b. Rimuovi lock files
# ---------------------------------------------------------------
log "Rimozione lock files mhvtl..."
find /var/lock /tmp /run -name "*mhvtl*" -o -name "*vtl*q*" \
  2>/dev/null | while read F; do
  rm -f "${F}" && log2 "Rimosso: ${F}"
done
find "${MHVTL_DIR}" "${MHVTL_CONF}" \
  -name "*.lock" -o -name "*.pid" \
  2>/dev/null | while read F; do
  rm -f "${F}" && log2 "Rimosso: ${F}"
done

# ---------------------------------------------------------------
# 3. Rimozione device SCSI mhvtl dal sottosistema kernel
#    OBBLIGATORIO prima di rmmod — altrimenti scsi_mod
#    tiene mhvtl in uso e rmmod fallisce
# ---------------------------------------------------------------
log "Rimozione device SCSI mhvtl dal sottosistema kernel..."

MHVTL_HOST=""
for HOST in /sys/class/scsi_host/host*/; do
  PROC=$(cat "${HOST}proc_name" 2>/dev/null || true)
  if [ "${PROC}" = "mhvtl" ]; then
    MHVTL_HOST=$(basename "${HOST}" | sed 's/host//')
    log2 "Host SCSI mhvtl trovato: host${MHVTL_HOST}"
    break
  fi
done

if [ -n "${MHVTL_HOST}" ]; then
  # Rimuovi tutti i device SCSI sotto l'host mhvtl
  for DEV in /sys/class/scsi_device/${MHVTL_HOST}\:*; do
    [ -e "${DEV}" ] || continue
    DEVNAME=$(basename "${DEV}")
    log2 "Rimozione device SCSI ${DEVNAME}..."
    echo 1 > "/sys/class/scsi_device/${DEVNAME}/device/delete" 2>/dev/null \
      && log2 "  OK" \
      || warn "  impossibile rimuovere ${DEVNAME} via sysfs"
  done
  sleep 1
else
  log2 "Nessun host SCSI mhvtl trovato — già rimosso."
fi

# ---------------------------------------------------------------
# 4. Rimuovi /dev/mhvtl
# ---------------------------------------------------------------
log "Rimozione device node /dev/mhvtl..."
if [ -c /dev/mhvtl ]; then
  rm -f /dev/mhvtl
  log2 "/dev/mhvtl rimosso."
else
  log2 "/dev/mhvtl non presente."
fi

# ---------------------------------------------------------------
# 5. Scarica moduli kernel nell'ordine corretto:
#    st prima (rilascia /dev/st* e /dev/nst*)
#    mhvtl dopo (ora refcnt dovrebbe essere 0)
# ---------------------------------------------------------------
log "Scaricamento moduli kernel..."

if lsmod | grep "^st "; then
  if rmmod st 2>/dev/null; then
    log2 "Modulo st scaricato."
  else
    warn "rmmod st fallito — potrebbe essere usato da device fisici."
  fi
else
  log2 "Modulo st non caricato."
fi

sleep 1
REFCNT=$(cat /sys/module/mhvtl/refcnt 2>/dev/null || echo "0")
log2 "mhvtl refcnt: ${REFCNT}"

if lsmod | grep mhvtl; then
  if [ "${REFCNT}" = "0" ]; then
    if rmmod mhvtl 2>/dev/null; then
      log2 "Modulo mhvtl scaricato."
    else
      warn "rmmod mhvtl fallito nonostante refcnt=0."
    fi
  else
    warn "mhvtl refcnt=${REFCNT} — modulo ancora in uso."
    warn "I demoni sono fermi ma il modulo residua fino al prossimo riavvio."
    warn "Per scaricamento completo: sudo reboot"
  fi
else
  log2 "Modulo mhvtl non caricato."
fi

# Ricarica st per i drive fisici reali del sistema
modprobe st 2>/dev/null && log2 "Modulo st ricaricato per uso sistema." || true

# ---------------------------------------------------------------
# 6. Pulizia dati (solo se MHVTL_CLEAN=yes)
# ---------------------------------------------------------------
if [ "${MHVTL_CLEAN}" = "yes" ]; then
  log "MHVTL_CLEAN=yes — rimozione completa dati e configurazione..."

  for LIB_IDX in $(seq 1 ${MHVTL_LIBRARIES}); do
    LIB_Q=$((LIB_IDX * 10))
    if [ -d "${MHVTL_DIR}/${LIB_Q}" ]; then
      rm -rf "${MHVTL_DIR}/${LIB_Q}"
      log2 "Rimossa directory cartucce libreria ${LIB_IDX}: ${MHVTL_DIR}/${LIB_Q}"
    fi
    rm -f "${MHVTL_DIR}/library_contents.${LIB_Q}"
    log2 "Rimosso library_contents.${LIB_Q}"
  done

  if [ -d "${MHVTL_CONF}" ]; then
    rm -rf "${MHVTL_CONF}"
    log2 "Rimossa directory conf: ${MHVTL_CONF}"
  fi
  rm -rf "${MHVTL_DIR}"
  log "Reset completo eseguito."
  log "Per reinizializzare: make mhvtl-init"
else
  log "Dati conservati in ${MHVTL_DIR} (MHVTL_CLEAN=no)."
  log "Per reset completo:  make mhvtl-clean"
  log "Per riavviare:       make mhvtl-init"
fi

# ---------------------------------------------------------------
# 7. Riepilogo stato finale
# ---------------------------------------------------------------
PROCS_LIVE=$(pgrep -f "vtl(library|tape)" 2>/dev/null | wc -l)
MOD_STATUS=$(lsmod | grep mhvtl | awk '{print $1}' || echo "scaricato")
DEV_STATUS=$([ -c /dev/mhvtl ] && echo "presente" || echo "assente")
SCSI_LEFT=$(lsscsi -g 2>/dev/null | grep -c mhvtl || echo 0)

log ""
log "=== mhvtl arrestato ==="
log2 "Processi vtl attivi : ${PROCS_LIVE}"
log2 "Modulo kernel       : ${MOD_STATUS}"
log2 "/dev/mhvtl          : ${DEV_STATUS}"
log2 "Device SCSI mhvtl   : ${SCSI_LEFT}"