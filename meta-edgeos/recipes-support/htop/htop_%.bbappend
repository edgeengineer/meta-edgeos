FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://htoprc"

do_install:append() {
  install -d ${D}${sysconfdir}
  install -m 0644 ${WORKDIR}/htoprc ${D}${sysconfdir}/htoprc
}
