
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "U-Boot package group"
RDEPENDS:${PN} = " \
    u-boot-fw-utils \
    "
