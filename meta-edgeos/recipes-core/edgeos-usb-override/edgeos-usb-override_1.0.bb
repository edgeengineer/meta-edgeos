SUMMARY = "EdgeOS USB Override"
DESCRIPTION = "Cleans up NVIDIA USB gadget configuration for EdgeOS custom setup"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://edgeos-usb-override.sh \
    file://edgeos-usb-override.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-usb-override.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install USB override script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/edgeos-usb-override.sh ${D}${bindir}/

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-usb-override.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${bindir}/edgeos-usb-override.sh"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-usb-override.service"

RDEPENDS:${PN} = "bash"
