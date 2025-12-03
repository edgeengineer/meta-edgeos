
inherit journal-persist

# make sure the systemd recipe builds the networkd and resolved subpackages
# resolved is needed for proper DNS resolution in containers
PACKAGECONFIG:append = " networkd resolved"

# Configure systemd-resolved for proper DNS in containers
do_install:append() {
    # Enable systemd-resolved service
    install -d ${D}${sysconfdir}/systemd/system/multi-user.target.wants
    ln -sf ${systemd_system_unitdir}/systemd-resolved.service \
        ${D}${sysconfdir}/systemd/system/multi-user.target.wants/systemd-resolved.service

    # Configure resolved to create /run/systemd/resolve/resolv.conf
    # This file contains actual DNS servers (not the 127.0.0.53 stub)
    install -d ${D}${sysconfdir}/systemd/resolved.conf.d
    cat > ${D}${sysconfdir}/systemd/resolved.conf.d/10-edgeos.conf << 'EOF'
[Resolve]
# Use this for fallback DNS if no other DNS is available
FallbackDNS=8.8.8.8 1.1.1.1
# Don't use LLMNR (Link-Local Multicast Name Resolution)
LLMNR=no
# Use mDNS for .local domains (Avahi compatibility)
MulticastDNS=yes
EOF
}

# systemd persistent log
# Install the drop-in and tmpfiles rule ONLY when this feature is enabled.
do_install:append:journal_persist-on() {
    # journald drop-in to force persistence
    install -d ${D}${sysconfdir}/systemd/journald.conf.d
    cat > ${D}${sysconfdir}/systemd/journald.conf.d/10-persistent.conf << 'EOF'
[Journal]
# Persist logs under /var/log/journal
Storage=persistent
EOF

    # tmpfiles rule to ensure the directory exists with correct perms
    install -d ${D}${libdir}/tmpfiles.d
    cat > ${D}${libdir}/tmpfiles.d/50-journald-persistent.conf << 'EOF'
# type path                 mode  user group             age argument
d     /var/log/journal      2755  root systemd-journal   -   -
EOF
}

# Ship systemd-resolved configuration
FILES:${PN}:append = " \
    ${sysconfdir}/systemd/system/multi-user.target.wants/systemd-resolved.service \
    ${sysconfdir}/systemd/resolved.conf.d/10-edgeos.conf \
    "

# systemd persistent log
# Only ship these files when the feature is enabled.
FILES:${PN}:append:journal_persist-on = " \
    ${sysconfdir}/systemd/journald.conf.d/10-persistent.conf \
    ${libdir}/tmpfiles.d/50-journald-persistent.conf \
    "
