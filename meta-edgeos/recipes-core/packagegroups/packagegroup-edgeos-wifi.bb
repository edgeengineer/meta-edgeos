
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "WiFi package group"
RDEPENDS:${PN} = " \
    wireless-regdb-static \
    libnl \
    libnl-route \
    "

# Note: WiFi firmware (linux-firmware-rpidistro-bcm43455) is automatically
# included via MACHINE_EXTRA_RRECOMMENDS in meta-raspberrypi's machine config

RDEPENDS:${PN}:append = "\
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_DEBUG') == '1', \
        ' \
            iw \
        ', \
        '' \
        )} \
    "
