inherit partuuid

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://fstab"

do_install:append() {
    # Process fstab template with dynamic UUIDs from partuuid class
    install -m 0644 ${WORKDIR}/fstab ${D}${sysconfdir}/fstab

    # Replace UUID placeholders with actual values
    sed -i 's/RPI_BOOT_UUID/${EDGE_BOOT_PARTUUID}/g' ${D}${sysconfdir}/fstab
    sed -i 's/RPI_ROOT_UUID/${EDGE_ROOT_PARTUUID}/g' ${D}${sysconfdir}/fstab
}

# Make UUID changes trigger rebuilds wherever they’re used
do_install[vardeps] += "EDGE_BOOT_PARTUUID EDGE_ROOT_PARTUUID"
