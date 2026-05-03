# ================================================================
# Bareos Storage Daemon
# ================================================================

Storage {
  Name            = "${SD_NAME}"
  SDPort          = 9103
  WorkingDirectory = /var/lib/bareos  
  PluginDirectory = /usr/lib/bareos/plugins
  Maximum Concurrent Jobs = 20
  SDAddress       = 0.0.0.0
}

# ----------------------------------------------------------------
# Director autorizzato a connettersi a questo SD
# ----------------------------------------------------------------
Director {
  Name     = bareos-dir
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
  Monitor  = no
}

# ----------------------------------------------------------------
# Device — caricato dinamicamente dall'entrypoint-sd.sh
# Il file active-autochanger.conf viene selezionato in base a
# TAPE_DEVICE: vuoto=dev | /dev/sg*=mhvtl | /dev/nst*=prod
# ----------------------------------------------------------------
@/etc/bareos/bareos-sd.d/device/active-autochanger.conf

# ----------------------------------------------------------------
# Messaggi
# ----------------------------------------------------------------
Messages {
  Name    = Standard
  Director = bareos-dir = All
}