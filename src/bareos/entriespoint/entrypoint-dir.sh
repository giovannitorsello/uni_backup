#!/bin/bash
set -euo pipefail

log() { echo "[bareos-dir] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa i template di configurazione con envsubst
#    Le variabili sostituite sono elencate esplicitamente per
#    evitare di toccare eventuali ${...} nel config Bareos stesso
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."
echo "[DEBUG RUNTIME] Verifico variabili d'ambiente:"
echo "DB_NAME: $BAREOS_DB_NAME"
echo "DB_HOST: $BAREOS_DB_HOST"
echo "DB_PORT: $BAREOS_DB_PORT"
echo "DB_USER: $BAREOS_DB_USER"
echo "DB_USER: $BAREOS_DB_PASSWORD"
echo "DB_PASSWORD: $BAREOS_DB_PASSWORD"
echo "DIRECTOR_PASSWORD: $BAREOS_DIRECTOR_PASSWORD"
echo "SMTP_USER: $BAREOS_SMTP_USER"
echo "SMTP_PASSWORD: $BAREOS_SMTP_PASSWORD"
echo "SMTP_HOST: $BAREOS_SMTP_HOST"
echo "SMTP_PORT: $BAREOS_SMTP_PORT"

which envsubst || echo "ERRORE: envsubst NON TROVATO"

export BAREOS_DB_NAME BAREOS_DB_HOST BAREOS_DB_PORT BAREOS_DB_USER BAREOS_DB_PASSWORD
export BAREOS_SMTP_HOST BAREOS_SMTP_PORT BAREOS_SMTP_USER BAREOS_SMTP_PASSWORD
export BAREOS_DIRECTOR_PASSWORD BAREOS_SD_PASSWORD

# 2. Usa envsubst SENZA filtri
# Questo sostituirà OGNI variabile definita nell'ambiente
envsubst < /etc/bareos/templates/bareos-dir.conf.tpl > /etc/bareos/bareos-dir.conf
envsubst < /etc/bareos/templates/bareos-console.conf.tpl > /etc/bareos/bconsole.conf
log "Template elaborati."

# ---------------------------------------------------------------
# 2. Attendi che PostgreSQL sia pronto
# ---------------------------------------------------------------
log "Attesa PostgreSQL su ${BAREOS_DB_HOST}:${BAREOS_DB_PORT:-5432}..."
until pg_isready \
    -h "${BAREOS_DB_HOST}" \
    -p "${BAREOS_DB_PORT:-5432}" \
    -U "${BAREOS_DB_USER}" \
    -d "${BAREOS_DB_NAME}" \
    2>/dev/null; do
  log "  PostgreSQL non pronto, ritento tra 3 secondi..."
  sleep 3
done
log "PostgreSQL pronto."

# ---------------------------------------------------------------
# 3. Inizializza il catalogo Bareos se necessario
#    Usa le variabili standard PostgreSQL per psql e per gli
#    script Bareos (che leggono db_user, db_host ecc.)
# ---------------------------------------------------------------
export PGDATABASE="${BAREOS_DB_NAME}"
export PGHOST="${BAREOS_DB_HOST}"
export PGPORT="${BAREOS_DB_PORT:-5432}"
export PGUSER="${BAREOS_DB_USER}"
export PGPASSWORD="${BAREOS_DB_PASSWORD}"

# Variabili lette dagli script Bareos create_bareos_database ecc.
export db_name="${BAREOS_DB_NAME}"
export db_host="${BAREOS_DB_HOST}"
export db_port="${BAREOS_DB_PORT:-5432}"
export db_user="${BAREOS_DB_USER}"
export db_password="${BAREOS_DB_PASSWORD}"

if ! psql -c "SELECT 1 FROM Job LIMIT 1" > /dev/null 2>&1; then
  log "Prima esecuzione: inizializzazione catalogo Bareos..."

  SCRIPTS=/usr/lib/bareos/scripts

  log "  create_bareos_database..."
  "${SCRIPTS}/create_bareos_database" 2>&1 | sed 's/^/    /' || true

  log "  make_bareos_tables..."
  "${SCRIPTS}/make_bareos_tables" 2>&1 | sed 's/^/    /'

  log "  grant_bareos_privileges..."
  "${SCRIPTS}/grant_bareos_privileges" 2>&1 | sed 's/^/    /'

  log "Catalogo inizializzato."
else
  log "Catalogo esistente, skip inizializzazione."
fi

# ---------------------------------------------------------------
# 4. Avvia il Director in foreground
# ---------------------------------------------------------------
log "Sistemazione permessi directory..."
chown bareos:bareos /etc/bareos/bareos-dir.conf /etc/bareos/bconsole.conf
chown -R bareos:bareos /etc/bareos  /var/lib/bareos /var/log/bareos /run/bareos
chmod -R 750 /etc/bareos /var/lib/bareos /var/log/bareos /var/run/bareos

log "Avvio bareos-dir..."
exec /usr/sbin/bareos-dir \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-dir.conf
