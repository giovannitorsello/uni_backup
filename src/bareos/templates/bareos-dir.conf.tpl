# ================================================================
# Bareos Director — configurazione principale
# Generato da envsubst al primo avvio del container
# ================================================================

Director {                            # <--- Inizio risorsa
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  Maximum Concurrent Jobs = 10
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
  Messages = Standard
  WorkingDirectory = /var/lib/bareos
}

# ----------------------------------------------------------------
# Catalogo — PostgreSQL
# ----------------------------------------------------------------
Catalog {
  Name        = MyCatalog  
  DB Name     = ${BAREOS_DB_NAME}
  DB Address  = ${BAREOS_DB_HOST}
  DB Port     = ${BAREOS_DB_PORT}
  DB User     = ${BAREOS_DB_USER}
  DB Password = ${BAREOS_DB_PASSWORD}
}

# ----------------------------------------------------------------
# Messaggi
# ----------------------------------------------------------------
Messages {
  Name = Standard
  Mail Command = "/usr/lib/bareos/scripts/bsmtp -h ${BAREOS_SMTP_HOST}:${BAREOS_SMTP_PORT} -f ${BAREOS_SMTP_USER} -s \"Bareos: %t %e di %c %l\" %r"
  
  # CORREZIONE: In Messages si usa 'mail = destinatario = tipi_di_messaggio'
  mail = ${BAREOS_SMTP_USER} = all, !skipped, !saved, !audit
  
  operator = ${BAREOS_SMTP_USER} = mount
  console = all, !skipped, !saved, !audit
  append = "/var/log/bareos/bareos.log" = all, !skipped, !saved, !audit
  catalog = all, !skipped, !saved, !audit
}

Messages {
  Name     = Daemon
  Append   = "/var/log/bareos/bareos.log" = All, !Skipped, !Audit
  Console  = All, !Skipped, !Audit
}

# ----------------------------------------------------------------
# Console — accesso bconsole
# ----------------------------------------------------------------
Console {
  Name     = bareos-mon
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
  CommandACL = status, .status
}

# ----------------------------------------------------------------
# Storage - Emulazione librerie nastro
# ----------------------------------------------------------------

# Definizione della Libreria 1 nel Director
Storage {
  Name = mhvtl-Library-1
  Address = ueb-bareos-storage
  Password = "${BAREOS_SD_PASSWORD}"
  Device = mhvtl-Library-1
  Media Type = LTO8-L1
  Autochanger = yes
  Maximum Concurrent Jobs = 4
  SD Port = 9103
}

# Definizione della Libreria 2 nel Director
Storage {
  Name = mhvtl-Library-2
  Address = ueb-bareos-storage
  Password = "${BAREOS_SD_PASSWORD}"
  Device = mhvtl-Library-2
  Media Type = LTO8-L2
  Autochanger = yes
  Maximum Concurrent Jobs = 4
  SD Port = 9103
}

# 1. Definizione di cosa salvare
FileSet {
  Name = "SelfTest"
  Include {
    Options { signature = MD5 }
    File = "/etc/bareos"
  }
}

# 2. Definizione di dove salvare (punta al nome del tuo Storage)
Storage {
  Name = File
  Address = ueb-bareos-sd                # Indirizzo Docker del SD
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
  Device = FileStorage
  Media Type = File
}

# 3. Definizione del Client (punta al nome del tuo FD)
Client {
  Name = bareos-fd
  Address = ueb-bareos-fd                # Indirizzo Docker del FD
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
}

# 4. Pool di conservazione
Pool {
  Name = Default
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 365 days
}

# 5. IL JOB (Quello che mancava)
Job {
  Name = "BackupSelf"
  Type = Backup
  Level = Full
  Client = bareos-fd
  FileSet = "SelfTest"
  Storage = File
  Pool = Default
  Messages = Standard
  Priority = 10
}