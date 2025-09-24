
SUMMARY = "USB gadget setup"
DESCRIPTION = "Creates a composite USB Ethernet gadget"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://usb-gadget.sh \
    file://usb-gadget-prepare.service \
    file://usb-gadget-unbind.service \
    file://90-usb0-up.rules \
    file://99-usb-gadget-udc.rules \
    file://10-usb0.network \
    file://usb0-force-up \
    "

S = "${WORKDIR}"

inherit systemd

do_install() {
    # main script - install with EdgeOS branding
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/usb-gadget.sh ${D}${sbindir}/edgeos-usbgadget.sh
    # Create compatibility symlink
    ln -sf edgeos-usbgadget.sh ${D}${sbindir}/usb-gadget.sh

    # helper that forces usb0 admin-UP
    install -d ${D}${libexecdir}
    install -m 0755 ${WORKDIR}/usb0-force-up ${D}${libexecdir}

    # systemd units - install with EdgeOS branding
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/usb-gadget-prepare.service ${D}${systemd_unitdir}/system/edgeos-usbgadget-prepare.service
    install -m 0644 ${WORKDIR}/usb-gadget-unbind.service  ${D}${systemd_unitdir}/system/edgeos-usbgadget-unbind.service

    # udev rule
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/90-usb0-up.rules ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-usb-gadget-udc.rules ${D}${sysconfdir}/udev/rules.d

    # systemd-networkd config (Pi=192.168.7.1/24, host via DHCP=.2)
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-usb0.network ${D}${sysconfdir}/systemd/network

    # Update service files to reference the renamed script
    sed -i 's|/usr/sbin/usb-gadget.sh|/usr/sbin/edgeos-usbgadget.sh|g' \
        ${D}${systemd_unitdir}/system/edgeos-usbgadget-prepare.service
    sed -i 's|/usr/sbin/usb-gadget.sh|/usr/sbin/edgeos-usbgadget.sh|g' \
        ${D}${systemd_unitdir}/system/edgeos-usbgadget-unbind.service
    
    # Update udev rules to reference the renamed services
    sed -i 's|usb-gadget-unbind.service|edgeos-usbgadget-unbind.service|g' \
        ${D}${sysconfdir}/udev/rules.d/99-usb-gadget-udc.rules
    
    # Update logging in the script to show EdgeOS branding
    sed -i 's|\[usb-gadget\]|[edgeos-usbgadget]|g' \
        ${D}${sbindir}/edgeos-usbgadget.sh
}

# Enable only the prepare service; bind/unbind are started by udev when needed
SYSTEMD_SERVICE:${PN} = "edgeos-usbgadget-prepare.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "udev kmod iproute2 systemd-networkd edgeos-utils"

FILES:${PN} += "\
    ${sbindir}/edgeos-usbgadget.sh \
    ${sbindir}/usb-gadget.sh \
    ${libexecdir}/usb0-force-up \
    ${systemd_unitdir}/system/edgeos-usbgadget-prepare.service \
    ${systemd_unitdir}/system/edgeos-usbgadget-unbind.service \
    ${sysconfdir}/udev/rules.d/90-usb0-up.rules \
    ${sysconfdir}/udev/rules.d/99-usb-gadget-udc.rules \
    ${sysconfdir}/systemd/network/10-usb0.network \
    "

# the split package name 'systemd-networkd' isn’t present in Scarthgap
# so we don't hard-require it
RDEPENDS:${PN}:remove = " systemd-networkd"
RDEPENDS:${PN} += " systemd"

# future proof (no-op on Scarthgap, useful on branches that split it):
# RRECOMMENDS:${PN} += " systemd-networkd"
