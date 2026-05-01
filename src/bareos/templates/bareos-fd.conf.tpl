# ================================================================
# Bareos File Daemon (client)
# ================================================================

Client {
  Name            = ${FD_NAME}
  FDPort          = 9102
  WorkingDirectory = /var/lib/bareos
  PidDirectory    = /run/bareos
  PluginDirectory = /usr/lib/bareos/plugins
  MaximumConcurrentJobs = 10
}

# ----------------------------------------------------------------
# Director autorizzato a fare backup di questo client
# ----------------------------------------------------------------
Director {
  Name     = bareos-dir
  Password = "${DIRECTOR_PASSWORD}"
  Monitor  = no
}

# ----------------------------------------------------------------
# Messaggi
# ----------------------------------------------------------------
Messages {
  Name    = Standard
  Director = bareos-dir = All, !Skipped, !Restored
}