
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "WiFi package group"
RDEPENDS:${PN} = " \
    wireless-regdb-static \
    libnl \
    libnl-route \
    "

RDEPENDS:${PN}:append = "\
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_DEBUG') == '1', \
        ' \
            iw \
        ', \
        '' \
        )} \
    "
