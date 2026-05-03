# ================================================================
# bconsole — client console per il Director
# ================================================================

Director {
  Name     = ueb-bareos-director
  DIRport  = 9101
  Address  = ueb-bareos-director
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
}