# Explicitly enable WiFi support for connman
PACKAGECONFIG:append = " wifi"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://main.conf \
            file://wifi-rfkill-migrate.service \
            file://wifi-rfkill-migrate.sh \
            file://wifi-nudge.service \
            file://80-wireless.rules \
            file://85-wifi-regdomain.rules \
            file://regdomain \
            file://cfg80211.conf \
           "

inherit systemd

SYSTEMD_SERVICE:${PN} += "wifi-rfkill-migrate.service wifi-nudge.service"

do_install:append() {
    install -d ${D}${sysconfdir}/connman
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/connman/main.conf

    # Install one-time WiFi rfkill migration service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/wifi-rfkill-migrate.service ${D}${systemd_system_unitdir}/

    # Install WiFi registration nudge service
    install -m 0644 ${WORKDIR}/wifi-nudge.service ${D}${systemd_system_unitdir}/

    # Install migration script
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/wifi-rfkill-migrate.sh ${D}${sbindir}/

    # Install udev rules for WiFi
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/80-wireless.rules ${D}${sysconfdir}/udev/rules.d/
    install -m 0644 ${WORKDIR}/85-wifi-regdomain.rules ${D}${sysconfdir}/udev/rules.d/

    # Install default regulatory domain (US)
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/regdomain ${D}${sysconfdir}/regdomain

    # Install modprobe configuration to set global regulatory domain default
    # This sets the initial global domain; udev rule sends the PHY-specific hint
    install -d ${D}${sysconfdir}/modprobe.d
    install -m 0644 ${WORKDIR}/cfg80211.conf ${D}${sysconfdir}/modprobe.d/
}

FILES:${PN} += " \
    ${sysconfdir}/connman/main.conf \
    ${sysconfdir}/udev/rules.d/80-wireless.rules \
    ${sysconfdir}/udev/rules.d/85-wifi-regdomain.rules \
    ${sysconfdir}/regdomain \
    ${sysconfdir}/modprobe.d/cfg80211.conf \
    ${sbindir}/wifi-rfkill-migrate.sh \
    "

# udev rule uses iw to set regulatory domain
# systemd-rfkill persists WiFi enable/disable state
RDEPENDS:${PN} += "iw"
