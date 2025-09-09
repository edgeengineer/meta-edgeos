SUMMARY = "EdgeOS partition expansion for Mender A/B layout"
DESCRIPTION = "Automatically expands data partition on first boot to use available storage"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://expand-partitions.sh \
           file://expand-partitions.service"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "expand-partitions.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} = "bash e2fsprogs-resize2fs gptfdisk util-linux"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/expand-partitions.sh ${D}${sbindir}/
    
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/expand-partitions.service ${D}${systemd_system_unitdir}/
    
    # Create directory for marker file
    install -d ${D}${localstatedir}/lib/edgeos
}

FILES:${PN} = "${sbindir}/expand-partitions.sh \
               ${systemd_system_unitdir}/expand-partitions.service \
               ${localstatedir}/lib/edgeos"