# ================================================================
# Bareos Director — configurazione principale
# Generato da envsubst al primo avvio del container
# ================================================================

Director {
  Name        = bareos-dir
  QueryFile   = "/usr/lib/bareos/scripts/query.sql"
  WorkingDirectory = /var/lib/bareos
  PidDirectory     = /run/bareos
  LogTimestamp     = yes

  # Password usata da bconsole e Storage Daemon per autenticarsi
  Password    = "${BAREOS_DIRECTOR_PASSWORD}"

  # Audit log delle operazioni console
  Auditing    = yes
}

# ----------------------------------------------------------------
# Catalogo — PostgreSQL
# ----------------------------------------------------------------
Catalog {
  Name     = MyCatalog
  DB Driver = postgresql
  DB Name  = bareos
  DB Address = ${DB_HOST}
  DB Port    = ${DB_PORT}
  DB User    = ${DB_USER}
  DB Password = "${DB_PASSWORD}"
}

# ----------------------------------------------------------------
# Storage Daemon
# ----------------------------------------------------------------
# ── Storage Daemon — Libreria 1 ───────────────────────────────
Storage {
  Name      = mhvtl-Library-1
  Address   = bareos-storage
  SD Port   = 9103
  Password  = "${BAREOS_DIRECTOR_PASSWORD}"
  Device    = mhvtl-Library-1
  Media Type = LTO8-L1
}

# ── Storage Daemon — Libreria 2 ───────────────────────────────
Storage {
  Name      = mhvtl-Library-2
  Address   = bareos-storage
  SD Port   = 9103
  Password  = "${BAREOS_DIRECTOR_PASSWORD}"
  Device    = mhvtl-Library-2
  Media Type = LTO8-L2
}

# ── Pool per Libreria 1 ───────────────────────────────────────
Pool {
  Name            = Pool-L1-Full
  Pool Type       = Backup
  Storage         = mhvtl-Library-1
  Recycle         = yes
  AutoPrune       = yes
  Volume Retention = 365 days
  Maximum Volume Bytes = 12T
  Label Format    = "L1-Full-"
}

Pool {
  Name            = Pool-L1-Incremental
  Pool Type       = Backup
  Storage         = mhvtl-Library-1
  Recycle         = yes
  AutoPrune       = yes
  Volume Retention = 30 days
  Maximum Volume Bytes = 12T
  Label Format    = "L1-Inc-"
}

# ── Pool per Libreria 2 ───────────────────────────────────────
Pool {
  Name            = Pool-L2-Full
  Pool Type       = Backup
  Storage         = mhvtl-Library-2
  Recycle         = yes
  AutoPrune       = yes
  Volume Retention = 365 days
  Maximum Volume Bytes = 12T
  Label Format    = "L2-Full-"
}

Pool {
  Name            = Pool-L2-Incremental
  Pool Type       = Backup
  Storage         = mhvtl-Library-2
  Recycle         = yes
  AutoPrune       = yes
  Volume Retention = 30 days
  Maximum Volume Bytes = 12T
  Label Format    = "L2-Inc-"
}


# ----------------------------------------------------------------
# Schedule di default
# ----------------------------------------------------------------
Schedule {
  Name      = WeeklyCycle
  Run = Full         1st sat at 22:00
  Run = Differential 2nd-5th sat at 22:00
  Run = Incremental  mon-fri at 22:00
}

Schedule {
  Name      = MonthlyCycle
  Run = Full      1st sun at 01:00
  Run = Incremental mon-sat at 23:00
}

# ----------------------------------------------------------------
# FileSet di default — sovrascrivibile per cliente
# ----------------------------------------------------------------
FileSet {
  Name    = "LinuxAll"
  Include {
    Options {
      Signature   = MD5
      Compression = LZ4
      OneFS       = yes
    }
    File = /
  }
  Exclude {
    File = /proc
    File = /sys
    File = /tmp
    File = /var/tmp
    File = /.cache
    File = /var/cache
    File = /var/lib/bareos/storage
  }
}

FileSet {
  Name    = "WindowsAll"
  Include {
    Options {
      Signature   = MD5
      Compression = LZ4
      IgnoreCase  = yes
    }
    File = "C:/"
  }
  Exclude {
    File = "C:/Windows/Temp"
    File = "C:/pagefile.sys"
    File = "C:/hiberfil.sys"
  }
}

# ----------------------------------------------------------------
# Messaggi
# ----------------------------------------------------------------
Messages {
  Name     = Standard
  MailCommand  = "/usr/lib/bareos/scripts/bsmtp \
                   -h ${SMTP_HOST}:${SMTP_PORT} \
                   -f ${SMTP_FROM} \
                   -s \"Bareos: %t %e di %c %l\" %r"
  Mail On Error = "${SMTP_USER}"
  Mail On Success = "${SMTP_USER}"
  Append  = "/var/log/bareos/bareos.log" = All, !Skipped, !Saved, !Audit
  Catalog = All, !Skipped, !Saved, !Audit
  Console = All, !Skipped, !Saved, !Audit
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