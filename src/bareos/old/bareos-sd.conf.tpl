Storage {
  Name       = ${SD_NAME}
  SDPort     = 9103
  WorkingDirectory     = "/var/lib/bareos"
  PidDirectory         = "/run/bareos"
  Plugin Directory     = "/usr/lib/bareos/plugins"
  Maximum Concurrent Jobs = 20
}

Director {
  Name     = bareos-dir
  Password = "${DIRECTOR_PASSWORD}"
}

Messages {
  Name    = Standard
  Director = bareos-dir = all
}

Device {
  Name            = LTO-Dr-01
  Media Type      = LTO-7
  Archive Device  = /dev/nst0
  AutomaticMount  = yes
  AlwaysOpen      = no
  RemovableMedia  = yes
  RandomAccess    = no
  Label Media     = yes
  Fast Forward Space File = no
  BSF at EOM      = yes
  Backward Space Record = no
  Two EOF         = yes
}
