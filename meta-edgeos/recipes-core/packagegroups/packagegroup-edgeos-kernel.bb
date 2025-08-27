
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Kernel package group"
RDEPENDS:${PN} = " \
    kernel-module-option \
    kernel-module-usb-wwan \
    kernel-module-usbserial \
    libubootenv \
    "
