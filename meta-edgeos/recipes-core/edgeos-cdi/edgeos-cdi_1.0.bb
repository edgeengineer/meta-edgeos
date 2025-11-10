SUMMARY = "EdgeOS CDI Spec Generation"
DESCRIPTION = "Generates Container Device Interface specs for NVIDIA GPUs on EdgeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://edgeos-cdi-generate.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-cdi-generate.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-cdi-generate.service ${D}${systemd_system_unitdir}/

    # Create CDI directory
    install -d ${D}/var/run/cdi
}

FILES:${PN} += "${systemd_system_unitdir}/edgeos-cdi-generate.service"
FILES:${PN} += "/var/run/cdi"

RDEPENDS:${PN} = "nvidia-container-toolkit"
