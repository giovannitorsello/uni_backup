# ================================================================
# bconsole — client console per il Director
# ================================================================

Director {
  Name     = bareos-dir
  DIRport  = 9101
  Address  = bareos-director
  Password = "${BAREOS_DIRECTOR_PASSWORD}"
}