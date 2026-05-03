# ================================================================
# Autochanger mhvtl — 2 librerie virtuali
# Libreria 1: changer /dev/sg3, drive /dev/nst0 /dev/nst1
# Libreria 2: changer /dev/sg6, drive /dev/nst2 /dev/nst3
# Adatta i device in base all'output di: lsscsi -g
# ================================================================

# ── Libreria 1 ────────────────────────────────────────────────
Autochanger {
  Name            = mhvtl-Library-1
  Device          = mhvtl-L1-Drive1, mhvtl-L1-Drive2, mhvtl-L1-Drive3, mhvtl-L1-Drive4
  Changer Command = "/usr/lib/bareos/scripts/mtx-changer %c %o %S %a %d"
  Changer Device  = ${CHANGER_DEVICE_1}
}

Device {
  Drive Index = 0
  Name              = mhvtl-L1-Drive1
  Media Type        = LTO8-L1
  Archive Device    = ${TAPE_AUTOCH1_DEVICE_1}
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
}

Device {
  Drive Index = 1
  Name              = mhvtl-L1-Drive2
  Media Type        = LTO8-L1
  Archive Device    = ${TAPE_AUTOCH1_DEVICE_2}
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
}

Device {
  Drive Index = 2
  Name              = mhvtl-L1-Drive3
  Media Type        = LTO8-L1
  Archive Device    = ${TAPE_AUTOCH1_DEVICE_3}
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
}

Device {
  Drive Index = 3
  Name              = mhvtl-L1-Drive4
  Media Type        = LTO8-L1
  Archive Device    = ${TAPE_AUTOCH1_DEVICE_4}
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
}

# ── Libreria 2 ────────────────────────────────────────────────
Autochanger {
  Name            = mhvtl-Library-2
  Device          = mhvtl-L2-Drive1, mhvtl-L2-Drive2, mhvtl-L2-Drive3, mhvtl-L2-Drive4
  Changer Command = "/usr/lib/bareos/scripts/mtx-changer %c %o %S %a %d"
  Changer Device  = ${CHANGER_DEVICE_2}
}

Device {
  Drive Index = 0
  Name              = mhvtl-L2-Drive1
  Media Type        = LTO8-L2
  Archive Device    = ${TAPE_AUTOCH2_DEVICE_1}
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
}

Device {
  Drive Index = 1
  Name              = mhvtl-L2-Drive2
  Media Type        = LTO8-L2
  Archive Device    = ${TAPE_AUTOCH2_DEVICE_2}
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
}

Device {
  Drive Index = 2
  Name              = mhvtl-L2-Drive3
  Media Type        = LTO8-L2
  Archive Device    = ${TAPE_AUTOCH2_DEVICE_3}
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
}

Device {
  Drive Index = 3
  Name              = mhvtl-L2-Drive4
  Media Type        = LTO8-L2
  Archive Device    = ${TAPE_AUTOCH2_DEVICE_4}
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
}