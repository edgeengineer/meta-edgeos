SUMMARY = "First-boot rootfs auto-expansion service"
DESCRIPTION = "Expands the active root partition and grows the filesystem on first boot."
LICENSE = "CLOSED"

SRC_URI = " \
    file://expand-rootfs.sh \
    file://expand-rootfs.service \
"

S = "${WORKDIR}"

inherit systemd

do_install() {
    install -d ${D}/usr/local/sbin
    install -m 0755 ${WORKDIR}/expand-rootfs.sh ${D}/usr/local/sbin/expand-rootfs.sh

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/expand-rootfs.service ${D}${systemd_unitdir}/system/expand-rootfs.service
}

FILES:${PN} += " \
    /usr/local/sbin/expand-rootfs.sh \
    ${systemd_unitdir}/system/expand-rootfs.service \
"

SYSTEMD_SERVICE:${PN} = "expand-rootfs.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} = "bash coreutils util-linux parted e2fsprogs-resize2fs udev gptfdisk"

