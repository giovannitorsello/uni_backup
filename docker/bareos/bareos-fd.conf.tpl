FileDaemon {
  Name     = ${FD_NAME}
  FDport   = 9102
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory     = "/run/bareos"
  Plugin Directory = "/usr/lib/bareos/plugins"
  Maximum Concurrent Jobs = 10
}

Director {
  Name     = bareos-dir
  Password = "${DIRECTOR_PASSWORD}"
}

Messages {
  Name    = Standard
  Director = bareos-dir = all
}
