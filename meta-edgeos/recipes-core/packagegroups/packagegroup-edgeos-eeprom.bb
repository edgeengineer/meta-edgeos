SUMMARY = "EdgeOS EEPROM Configuration Package Group"
DESCRIPTION = "Package group for Raspberry Pi EEPROM configuration and management"
LICENSE = "MIT"

inherit packagegroup

RDEPENDS:${PN} = " \
    rpi-eeprom \
    rpi-eeprom-config \
"

# This package group is only relevant for Raspberry Pi platforms
COMPATIBLE_MACHINE = "^rpi$"