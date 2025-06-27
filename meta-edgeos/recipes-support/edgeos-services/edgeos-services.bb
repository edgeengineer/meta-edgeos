SUMMARY = "EdgeOS system services and configuration"
DESCRIPTION = "SystemD services and scripts for EdgeOS USB gadget and device management"
LICENSE = "CLOSED"

SRC_URI = " \
    file://edgeos-usbgadget.service \
    file://edgeos-usbgadget-init.sh \
    file://edgeos-usbgadget-resume.sh \
    file://edgeos-mdns-setup.service \
    file://generate-uuid.sh \
    file://update-edgeos-dns-service.sh \
    file://edgeos-dns.service \
    file://90-edgeos-usbgadget.rules \
    file://edgeos-usb-modules.conf \
    file://edgeos-jetson-modules.conf \
    file://edgeos-journal.conf \
    file://10-edgeos-header \
    file://edge_welcome.txt \
    file://first-boot-timesync.service \
    file://timesyncd.conf \
    file://edgeos-usb-override.service \
    file://edgeos-usb-override.sh \
    file://edgeos-usb-debug.sh \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = " \
    systemd \
    avahi-daemon \
    avahi-utils \
    bash \
    util-linux \
    coreutils \
    networkmanager \
    networkmanager-nmcli \
    udev \
    kmod \
    iproute2 \
    iputils-ping \
    file \
    sed \
    grep \
    findutils \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = " \
    edgeos-usbgadget.service \
    edgeos-mdns-setup.service \
    first-boot-timesync.service \
    edgeos-usb-override.service \
"

SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install systemd service files
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-usbgadget.service ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-mdns-setup.service ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/first-boot-timesync.service ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-usb-override.service ${D}${systemd_system_unitdir}
    
    # Install scripts to /usr/local/sbin (matches original setup)
    install -d ${D}/usr/local/sbin
    install -m 0755 ${WORKDIR}/edgeos-usbgadget-init.sh ${D}/usr/local/sbin/
    install -m 0755 ${WORKDIR}/edgeos-usbgadget-resume.sh ${D}/usr/local/sbin/
    install -m 0755 ${WORKDIR}/generate-uuid.sh ${D}/usr/local/sbin/
    install -m 0755 ${WORKDIR}/update-edgeos-dns-service.sh ${D}/usr/local/sbin/
    
    # Install additional scripts to /usr/local/bin
    install -d ${D}/usr/local/bin
    install -m 0755 ${WORKDIR}/edgeos-usb-override.sh ${D}/usr/local/bin/
    install -m 0755 ${WORKDIR}/edgeos-usb-debug.sh ${D}/usr/local/bin/
    
    # Install udev rules
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/90-edgeos-usbgadget.rules ${D}${sysconfdir}/udev/rules.d/
    
    # Install module configuration
    install -d ${D}${sysconfdir}/modules-load.d
    install -m 0644 ${WORKDIR}/edgeos-usb-modules.conf ${D}${sysconfdir}/modules-load.d/
    install -m 0644 ${WORKDIR}/edgeos-jetson-modules.conf ${D}${sysconfdir}/modules-load.d/
    
    # Install journal configuration
    install -d ${D}${sysconfdir}/systemd/journald.conf.d
    install -m 0644 ${WORKDIR}/edgeos-journal.conf ${D}${sysconfdir}/systemd/journald.conf.d/
    
    # Install timesyncd configuration
    install -d ${D}${sysconfdir}/systemd/timesyncd.conf.d
    install -m 0644 ${WORKDIR}/timesyncd.conf ${D}${sysconfdir}/systemd/timesyncd.conf.d/
    
    # Install MOTD header
    install -d ${D}${sysconfdir}/update-motd.d
    install -m 0755 ${WORKDIR}/10-edgeos-header ${D}${sysconfdir}/update-motd.d/
    
    # Install avahi service
    install -d ${D}${sysconfdir}/avahi/services
    install -m 0644 ${WORKDIR}/edgeos-dns.service ${D}${sysconfdir}/avahi/services/
    
    # Create EdgeOS directories
    install -d ${D}/etc/edgeos
    install -d ${D}/opt/edgeos/share
    
    # Install welcome text
    install -m 0644 ${WORKDIR}/edge_welcome.txt ${D}/opt/edgeos/share/
}

FILES:${PN} += " \
    /usr/local/sbin/* \
    /usr/local/bin/* \
    /opt/edgeos/* \
" 