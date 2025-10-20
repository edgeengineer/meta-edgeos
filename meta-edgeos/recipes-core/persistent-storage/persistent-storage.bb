SUMMARY = "Persistent data partition mount + setup"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
  file://data.mount \
  file://data-setup.service \
  file://data-setup.sh \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "data.mount data-setup.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/data.mount ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/data-setup.service ${D}${systemd_unitdir}/system/
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/data-setup.sh ${D}${bindir}/
}

FILES:${PN} += " \
  ${systemd_unitdir}/system/data.mount \
  ${systemd_unitdir}/system/data-setup.service \
  ${bindir}/data-setup.sh \
"