SUMMARY = "EdgeOS utility scripts"
DESCRIPTION = "Common utility scripts for EdgeOS including MAC address generation"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://edgeos-generate-mac"

S = "${WORKDIR}"

do_install() {
    # Install MAC generation utility
    install -d ${D}${libexecdir}
    install -m 0755 ${WORKDIR}/edgeos-generate-mac ${D}${libexecdir}/edgeos-generate-mac
}

FILES:${PN} = "${libexecdir}/edgeos-generate-mac"

# Runtime dependencies
RDEPENDS:${PN} = "coreutils"