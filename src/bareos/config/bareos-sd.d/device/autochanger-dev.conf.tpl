
# ----------------------------------------------------------------
# Autochanger virtuale — sviluppo e CI
# Simula una libreria a 4 slot con drive a file su disco.
# Le directory slot* vengono create dall'entrypoint-sd.sh
# ----------------------------------------------------------------

Autochanger {
  Name            = VirtualLibrary
  Device          = VirtualDrive0, VirtualDrive1
  Changer Command = "/usr/lib/bareos/scripts/mtx-changer %c %o %S %a %d"
  Changer Device  = /dev/null
}

Device {
  Name             = VirtualDrive0
  Media Type       = File
  Archive Device   = /var/lib/bareos/storage/slot0
  Device Type      = File
  LabelMedia       = yes
  AutomaticMount   = yes
  AlwaysOpen       = no
  RemovableMedia   = no
  AutoChanger      = yes
  # Simula capienza massima nastro LTO-8 (12 TB nativo)
  Maximum File Size = 12G
}

Device {
  Name             = VirtualDrive1
  Media Type       = File
  Archive Device   = /var/lib/bareos/storage/slot1
  Device Type      = File
  LabelMedia       = yes
  AutomaticMount   = yes
  AlwaysOpen       = no
  RemovableMedia   = no
  AutoChanger      = yes
  Maximum File Size = 12G
}

Device {
  Name             = VirtualDrive2
  Media Type       = File
  Archive Device   = /var/lib/bareos/storage/slot2
  Device Type      = File
  LabelMedia       = yes
  AutomaticMount   = yes
  AlwaysOpen       = no
  RemovableMedia   = no
  AutoChanger      = yes
  Maximum File Size = 12G
}

Device {
  Name             = VirtualDrive3
  Media Type       = File
  Archive Device   = /var/lib/bareos/storage/slot3
  Device Type      = File
  LabelMedia       = yes
  AutomaticMount   = yes
  AlwaysOpen       = no
  RemovableMedia   = no
  AutoChanger      = yes
  Maximum File Size = 12G
}