# ----------------------------------------------------------------
# Autochanger produzione — hardware reale
# TAPE_DEVICE=/dev/nst0  (drive singolo)
# Per librerie multi-drive aggiungere Drive1, Drive2...
# con i device fisici corrispondenti.
# ----------------------------------------------------------------

Autochanger {
  Name            = ProductionLibrary
  Device          = prod-Drive0
  Changer Command = "/usr/lib/bareos/scripts/mtx-changer %c %o %S %a %d"
  # Per drive singolo senza changer robot usare /dev/null
  # Per librerie LTO con robot usare /dev/sg0, /dev/sg1...
  Changer Device  = ${CHANGER_DEVICE:-/dev/null}
}

Device {
  Name              = prod-Drive0
  Media Type        = LTO
  Archive Device    = ${TAPE_DEVICE}
  Device Type       = Tape
  AutomaticMount    = yes
  AlwaysOpen        = yes
  RemovableMedia    = yes
  RandomAccess      = no
  AutoChanger       = yes
  Offline On Unmount = yes
  Hardware End Of Medium = yes
  Fast Forward Space File = yes
  BSF at EOM        = yes
  Two EOF           = yes
  Maximum Changer Wait = 120
  Maximum Rewind Wait  = 120
  Alert Command     = "sh -c 'echo Cartridge Alert: %d' "
}
