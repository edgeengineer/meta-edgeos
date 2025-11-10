SUMMARY = "EdgeOS Hostname Management"
DESCRIPTION = "Manages hostname based on device identity for EdgeOS devices"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://generate-hostname.sh \
    file://edgeos-hostname.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-hostname.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install hostname generation script
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/generate-hostname.sh ${D}${sbindir}/

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-hostname.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${sbindir}/generate-hostname.sh"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-hostname.service"

RDEPENDS:${PN} = "bash edgeos-identity avahi-daemon"
