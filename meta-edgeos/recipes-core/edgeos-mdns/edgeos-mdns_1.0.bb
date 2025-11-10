SUMMARY = "EdgeOS mDNS Configuration"
DESCRIPTION = "Configures Avahi mDNS with device identity for EdgeOS devices"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://edgeos-mdns.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-mdns.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-mdns.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/edgeos-mdns.service"

RDEPENDS:${PN} = "bash edgeos-identity avahi-daemon"
