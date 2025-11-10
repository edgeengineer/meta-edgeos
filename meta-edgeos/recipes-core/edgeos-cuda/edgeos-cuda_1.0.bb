SUMMARY = "EdgeOS CUDA Environment Detection"
DESCRIPTION = "Detects CUDA installation and generates environment configuration for EdgeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://generate-cuda-env.sh \
    file://edgeos-cuda-detect.service \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-cuda-detect.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install CUDA detection script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/generate-cuda-env.sh ${D}${bindir}/

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-cuda-detect.service ${D}${systemd_system_unitdir}/

    # Create directory for environment files
    install -d ${D}${sysconfdir}/default
}

FILES:${PN} += "${bindir}/generate-cuda-env.sh"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-cuda-detect.service"
FILES:${PN} += "${sysconfdir}/default"

RDEPENDS:${PN} = "bash"
