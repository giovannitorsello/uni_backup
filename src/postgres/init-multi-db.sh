#!/bin/bash
set -e

echo "[Postgres-Init] Inizio procedura di inizializzazione per Bareos..."

# 1. Creazione dell'Utenza (Role)
# Usiamo un blocco DO per verificare l'esistenza del ruolo ed evitare errori se già presente
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$BAREOS_DB_USER') THEN
            CREATE ROLE $BAREOS_DB_USER WITH LOGIN SUPERUSER PASSWORD '$BAREOS_DB_PASSWORD';
            RAISE NOTICE 'Utente % creato con successo.', '$BAREOS_DB_USER';
        ELSE
            RAISE NOTICE 'Utente % già esistente, salto creazione.', '$BAREOS_DB_USER';
        END IF;
    END
    \$$;
EOSQL

# 2. Creazione del Database
# Nota: CREATE DATABASE non può essere eseguito all'interno di un blocco DO (transazione).
# Controlliamo l'esistenza del DB tramite una query e lo creiamo se manca.
DB_EXISTS=$(psql -tAc "SELECT 1 FROM pg_database WHERE datname='$BAREOS_DB'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "[Postgres-Init] Creazione database $BAREOS_DB con owner $BAREOS_DB_USER..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
         -c "CREATE DATABASE $BAREOS_DB OWNER $BAREOS_DB_USER;"
else
    echo "[Postgres-Init] Database $BAREOS_DB già presente."
fi

# 3. Privilegi finali
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     -c "GRANT ALL PRIVILEGES ON DATABASE $BAREOS_DB TO $BAREOS_DB_USER;"

echo "[Postgres-Init] Configurazione completata con successo."
