SUMMARY = "EdgeOS Device Identity Management"
DESCRIPTION = "Generates and manages unique device UUID for EdgeOS devices"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://generate-uuid.sh \
    file://edgeos-identity.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-identity.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install UUID generation script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/generate-uuid.sh ${D}${bindir}/

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-identity.service ${D}${systemd_system_unitdir}/

    # Create directory for UUID storage
    install -d ${D}${sysconfdir}/edgeos
}

FILES:${PN} += "${bindir}/generate-uuid.sh"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-identity.service"
FILES:${PN} += "${sysconfdir}/edgeos"

RDEPENDS:${PN} = "bash util-linux-uuidgen"