Director {
  Name        = bareos-dir
  DIRport     = 9101
  QueryFile   = "/usr/lib/bareos/scripts/query.sql"
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory     = "/run/bareos"
  Maximum Concurrent Jobs = 10
  Password    = "${DIRECTOR_PASSWORD}"
  Messages    = Daemon
  Auditing    = yes
}

Catalog {
  Name       = MyCatalog
  dbname     = "${DB_NAME}"
  dbuser     = "${DB_USER}"
  dbpassword = "${DB_PASSWORD}"
  dbaddress  = "${DB_HOST}"
  dbport     = ${DB_PORT}
}

Storage {
  Name     = LTO-Dr-01
  Address  = bareos-storage
  SDPort   = 9103
  Password = "${DIRECTOR_PASSWORD}"
  Device   = LTO-Dr-01
  Media Type = LTO-7
  Maximum Concurrent Jobs = 10
}

Messages {
  Name    = Standard
  console = all, !skipped, !restored
  catalog = all
}

Messages {
  Name    = Daemon
  console = all, !skipped, !saved, !restored
}

Pool {
  Name             = Default
  Pool Type        = Backup
  Recycle          = yes
  AutoPrune        = yes
  Volume Retention = 180 days
  Maximum Volumes  = 3
  Label Format     = "VOL-DEFAULT-"
}

Pool {
  Name      = Scratch
  Pool Type = Scratch
}

@|"sh -c 'ls /etc/bareos/bareos-dir.d/*.conf 2>/dev/null | while read f; do echo @\${f}; done'"
