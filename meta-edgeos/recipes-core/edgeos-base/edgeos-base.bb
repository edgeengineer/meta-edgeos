SUMMARY = "EdgeOS base configuration"
DESCRIPTION = "Base configuration for EdgeOS including user setup and system configuration"
LICENSE = "CLOSED"

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-g 1000 netdev; -g 1001 docker"
USERADD_PARAM:${PN} = "-u 1000 -m -s /bin/sh -G sudo,dialout,audio,video,plugdev,users,netdev,docker edge"

RDEPENDS:${PN} = "sudo shadow"

do_install() {
    # Create EdgeOS system directories
    install -d ${D}/etc/edgeos
    install -d ${D}/opt/edgeos
}

pkg_postinst_ontarget:${PN} () {
    # Set edge user password (password: edge)
    echo 'edge:edge' | chpasswd
    
    # Ensure edge user is in docker group
    usermod -aG docker edge || true
    
    # Set proper permissions on EdgeOS directories
    chown -R edge:edge /opt/edgeos || true
    chown edge:edge /etc/edgeos || true
    
    # Set hostname to edgeos-device
    echo "edgeos-device" > /etc/hostname
}

FILES:${PN} += " \
    /opt/edgeos \
    /etc/edgeos \
" 