
# make sure the systemd recipe builds the networkd subpackage
PACKAGECONFIG:append = " networkd"

do_install:append() {
    # Create journal directory with proper permissions
    install -d -m 2755 ${D}${localstatedir}/log/journal

    # Set the systemd-journal group ownership (will be fixed at runtime)
    chown root:systemd-journal ${D}${localstatedir}/log/journal || true
}

FILES:${PN} += "${localstatedir}/log/journal"
