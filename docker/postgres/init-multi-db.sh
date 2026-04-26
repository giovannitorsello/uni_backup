#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE bareos;
  GRANT ALL PRIVILEGES ON DATABASE bareos TO $POSTGRES_USER;
EOSQL
echo "Database bareos creato"
