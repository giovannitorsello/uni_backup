#!/bin/bash
set -euo pipefail

log() { echo "[bareos-dir] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------
# 1. Processa i template di configurazione con envsubst
#    Le variabili sostituite sono elencate esplicitamente per
#    evitare di toccare eventuali ${...} nel config Bareos stesso
# ---------------------------------------------------------------
log "Elaborazione template configurazione..."

VARS='${DIRECTOR_PASSWORD} ${DB_HOST} ${DB_PORT} ${DB_NAME} ${DB_USER} ${DB_PASSWORD}'

envsubst "$VARS" \
  < /etc/bareos/templates/bareos-dir.conf.tpl \
  > /etc/bareos/bareos-dir.conf

envsubst '$DIRECTOR_PASSWORD' \
  < /etc/bareos/templates/bareos-console.conf.tpl \
  > /etc/bareos/bconsole.conf

chown bareos:bareos /etc/bareos/bareos-dir.conf /etc/bareos/bconsole.conf
log "Template elaborati."

# ---------------------------------------------------------------
# 2. Attendi che PostgreSQL sia pronto
# ---------------------------------------------------------------
log "Attesa PostgreSQL su ${DB_HOST}:${DB_PORT:-5432}..."
until pg_isready \
    -h "${DB_HOST}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
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
export PGHOST="${DB_HOST}"
export PGPORT="${DB_PORT:-5432}"
export PGUSER="${DB_USER}"
export PGPASSWORD="${DB_PASSWORD}"
export PGDATABASE="${DB_NAME}"

# Variabili lette dagli script Bareos create_bareos_database ecc.
export db_host="${DB_HOST}"
export db_port="${DB_PORT:-5432}"
export db_user="${DB_USER}"
export db_password="${DB_PASSWORD}"
export db_name="${DB_NAME}"

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
log "Avvio bareos-dir..."
exec /usr/sbin/bareos-dir \
  -f \
  -u bareos \
  -g bareos \
  -c /etc/bareos/bareos-dir.conf
