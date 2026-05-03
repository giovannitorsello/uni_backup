# ================================================================
# Bareos File Daemon (client)
# ================================================================

Client {
  Name            = ${FD_NAME}
  FDPort          = 9102
  WorkingDirectory = /var/lib/bareos  
  PluginDirectory = /usr/lib/bareos/plugins
  MaximumConcurrentJobs = 10
}

# ----------------------------------------------------------------
# Director autorizzato a fare backup di questo client
# ----------------------------------------------------------------
Director {
  Name     = bareos-dir
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
}

# ----------------------------------------------------------------
# Messaggi
# ----------------------------------------------------------------
Messages {
  Name    = Standard
  Director = bareos-dir = All, !Skipped, !Restored
}