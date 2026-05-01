#!/bin/bash
# ================================================================
# mhvtl-teardown.sh — Arresto e pulizia libreria nastro virtuale
#
# Parametri (override via .env o variabili shell):
#   MHVTL_DIR    directory dati cartucce  (default: /opt/mhvtl)
#   MHVTL_CONF   directory configurazione (default: /etc/mhvtl)
#   MHVTL_DRIVES numero drive             (default: 2)
#   MHVTL_CLEAN  rimuove dati e conf      (default: no)
#                  "yes"  → rimozione completa (reset totale)
#                  "no"   → arresta demoni ma conserva dati
#
# Utilizzo:
#   sudo bash mhvtl-teardown.sh              # arresta, conserva dati
#   sudo MHVTL_CLEAN=yes bash mhvtl-teardown.sh  # reset completo
# ================================================================
set -euo pipefail

MHVTL_DIR="${MHVTL_DIR:-/opt/mhvtl}"
MHVTL_CONF="${MHVTL_CONF:-/etc/mhvtl}"
MHVTL_DRIVES="${MHVTL_DRIVES:-2}"
MHVTL_CLEAN="${MHVTL_CLEAN:-no}"

LIB_Q=10
FIRST_DRIVE_Q=11

log()  { echo "[mhvtl-stop] $(date '+%H:%M:%S') $*"; }
warn() { echo "[mhvtl-stop] $(date '+%H:%M:%S') WARN: $*"; }

log "Configurazione:"
log "  MHVTL_DIR    = ${MHVTL_DIR}"
log "  MHVTL_CONF   = ${MHVTL_CONF}"
log "  MHVTL_DRIVES = ${MHVTL_DRIVES}"
log "  MHVTL_CLEAN  = ${MHVTL_CLEAN}"

# ---------------------------------------------------------------
# 1. Termina vtltape — un processo per ogni drive
# ---------------------------------------------------------------
log "Arresto vtltape (${MHVTL_DRIVES} drive)..."
for i in $(seq 1 ${MHVTL_DRIVES}); do
  DRIVE_Q=$((FIRST_DRIVE_Q + i - 1))
  PIDS=$(pgrep -f "vtltape -q ${DRIVE_Q}" 2>/dev/null || true)
  if [ -n "${PIDS}" ]; then
    log "  Termino vtltape drive ${i} (queue ${DRIVE_Q}, PID: ${PIDS})..."
    kill ${PIDS} 2>/dev/null || true
    # Attendi terminazione graceful (max 5s)
    for _ in $(seq 1 5); do
      pgrep -f "vtltape -q ${DRIVE_Q}" &>/dev/null || break
      sleep 1
    done
    # Forza se ancora in esecuzione
    PIDS=$(pgrep -f "vtltape -q ${DRIVE_Q}" 2>/dev/null || true)
    if [ -n "${PIDS}" ]; then
      warn "vtltape drive ${i} non risponde — kill -9..."
      kill -9 ${PIDS} 2>/dev/null || true
    fi
    log "  vtltape drive ${i} terminato."
  else
    log "  vtltape drive ${i} (queue ${DRIVE_Q}) non in esecuzione."
  fi
done

# ---------------------------------------------------------------
# 2. Termina vtllibrary — robot changer
# ---------------------------------------------------------------
log "Arresto vtllibrary (queue ${LIB_Q})..."
PIDS=$(pgrep -f "vtllibrary -q ${LIB_Q}" 2>/dev/null || true)
if [ -n "${PIDS}" ]; then
  log "  Termino vtllibrary (PID: ${PIDS})..."
  kill ${PIDS} 2>/dev/null || true
  for _ in $(seq 1 5); do
    pgrep -f "vtllibrary -q ${LIB_Q}" &>/dev/null || break
    sleep 1
  done
  PIDS=$(pgrep -f "vtllibrary -q ${LIB_Q}" 2>/dev/null || true)
  if [ -n "${PIDS}" ]; then
    warn "vtllibrary non risponde — kill -9..."
    kill -9 ${PIDS} 2>/dev/null || true
  fi
  log "  vtllibrary terminato."
else
  log "  vtllibrary non in esecuzione."
fi

# Verifica che non rimangano processi vtl orfani
ORPHANS=$(pgrep -f "vtl(library|tape)" 2>/dev/null || true)
if [ -n "${ORPHANS}" ]; then
  warn "Processi vtl orfani rilevati (PID: ${ORPHANS}) — kill -9..."
  kill -9 ${ORPHANS} 2>/dev/null || true
fi

# ---------------------------------------------------------------
# 3. Rimuovi /dev/mhvtl
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# 3. Rimuovi /dev/mhvtl
# ---------------------------------------------------------------
log "Rimozione device node /dev/mhvtl..."
if [ -c /dev/mhvtl ]; then
  rm -f /dev/mhvtl
  log "/dev/mhvtl rimosso."
else
  log "/dev/mhvtl non presente."
fi

# ---------------------------------------------------------------
# 4. Scarica il modulo kernel
#    I device SCSI mhvtl devono essere rimossi PRIMA di rmmod
#    altrimenti il modulo risulta "in uso" e rmmod fallisce
# ---------------------------------------------------------------
log "Scaricamento modulo kernel mhvtl..."
if lsmod | grep -q mhvtl; then

  # Rimuovi esplicitamente i device SCSI ancora registrati
  SCSI_HOSTS=$(ls /sys/bus/scsi/drivers/mhvtl/ 2>/dev/null || true)
  if [ -n "${SCSI_HOSTS}" ]; then
    log "Deregistrazione device SCSI mhvtl..."
    for HOST in /sys/class/scsi_host/host*/; do
      PROC=$(cat "${HOST}proc_name" 2>/dev/null || true)
      if [ "${PROC}" = "mhvtl" ]; then
        HOSTNUM=$(basename "${HOST}" | sed 's/host//')
        log "  Rimozione scsi host${HOSTNUM}..."
        echo 1 > "${HOST}scan" 2>/dev/null || true
      fi
    done
    sleep 1
  fi

  # Scarica il driver tape SCSI se caricato — rilascia i device /dev/st*
  if lsmod | grep -q "^st "; then
    rmmod st 2>/dev/null && log "Modulo st scaricato." || true
  fi

  # Forza rmmod con -f se necessario
  if rmmod mhvtl 2>/dev/null; then
    log "Modulo scaricato."
  else
    log "rmmod normale fallito — tento con -f (force)..."
    if rmmod -f mhvtl 2>/dev/null; then
      log "Modulo scaricato forzatamente."
    else
      log "WARN: impossibile scaricare il modulo."
      log "      Riavvia il sistema per liberare i device SCSI."
    fi
  fi
else
  log "Modulo già scaricato."
fi

# Verifica finale device SCSI
sleep 1
RESIDUI=$(lsscsi -g 2>/dev/null | grep -i mhvtl | wc -l)
if [ "${RESIDUI}" -gt 0 ]; then
  log "WARN: ${RESIDUI} device mhvtl ancora visibili — richiesto riavvio."
  log "      sudo reboot"
else
  log "Device SCSI mhvtl rimossi correttamente."
fi

# ---------------------------------------------------------------
# 5. Pulizia dati (solo se MHVTL_CLEAN=yes)
# ---------------------------------------------------------------
if [ "${MHVTL_CLEAN}" = "yes" ]; then
  log "MHVTL_CLEAN=yes — rimozione completa dati e configurazione..."

  if [ -d "${MHVTL_DIR}" ]; then
    rm -rf "${MHVTL_DIR}"
    log "  Rimossa directory dati: ${MHVTL_DIR}"
  else
    log "  Directory dati ${MHVTL_DIR} non presente."
  fi

  if [ -d "${MHVTL_CONF}" ]; then
    rm -rf "${MHVTL_CONF}"
    log "  Rimossa directory conf: ${MHVTL_CONF}"
  else
    log "  Directory conf ${MHVTL_CONF} non presente."
  fi

  log "Reset completo eseguito."
  log "Per reinizializzare: make mhvtl-init"
else
  log "Dati conservati in ${MHVTL_DIR} (MHVTL_CLEAN=no)."
  log "Per riavviare senza reinizializzare: make mhvtl-init"
  log "Per reset completo: make mhvtl-clean"
fi

# ---------------------------------------------------------------
# 6. Riepilogo stato finale
# ---------------------------------------------------------------
log ""
log "=== mhvtl arrestato ==="
log "  Processi vtl attivi : $(pgrep -f 'vtl(library|tape)' 2>/dev/null | wc -l)"
log "  Modulo kernel       : $(lsmod | grep -c mhvtl 2>/dev/null && echo 'caricato' || echo 'scaricato')"
log "  /dev/mhvtl          : $([ -c /dev/mhvtl ] && echo 'presente' || echo 'assente')"
log "  Device SCSI mhvtl   : $(lsscsi -g 2>/dev/null | grep -c mhvtl || echo 0)"