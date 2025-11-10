SUMMARY = "EdgeOS radvd Configuration"
DESCRIPTION = "IPv6 Router Advertisement Daemon systemd override for EdgeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://radvd.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "radvd.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install systemd service override
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/radvd.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/radvd.service"

RDEPENDS:${PN} = "radvd"
