SUMMARY = "EdgeOS base system configuration"
DESCRIPTION = "Base configuration for EdgeOS including users, groups, and system setup"
LICENSE = "CLOSED"

inherit useradd

USERADD_PACKAGES = "${PN}"
# Use -g for primary group and -G for supplementary groups
USERADD_PARAM:${PN} = "-d /home/edge -r -s /bin/bash -g edge -G dialout,audio,video,plugdev,users edge"
GROUPADD_PARAM:${PN} = "-r edge"

RDEPENDS:${PN} = " \
    sudo \
    shadow \
"

do_install() {
    # Create the edge user's home directory (ownership will be set by useradd)
    install -d ${D}/home/edge
    
    # Create /boot/firmware directory for Pi 5 compatibility
    install -d ${D}/boot/firmware
}

# Use pkg_postinst_ontarget to avoid conflicts with base-files
pkg_postinst_ontarget:${PN}() {
    # Set hostname to edgeos-device
    echo "edgeos-device" > /etc/hostname
    
    # Update /etc/hosts
    sed -i '/127.0.1.1/d' /etc/hosts
    echo "127.0.1.1    edgeos-device" >> /etc/hosts
    
    # Ensure proper ownership of edge user's home directory
    chown -R edge:edge /home/edge 2>/dev/null || true
    
    # Add edge user to additional groups that may not exist during build
    usermod -aG sudo edge 2>/dev/null || true
    usermod -aG netdev edge 2>/dev/null || true
    usermod -aG input edge 2>/dev/null || true
    usermod -aG spi edge 2>/dev/null || true
    usermod -aG i2c edge 2>/dev/null || true
    usermod -aG gpio edge 2>/dev/null || true
}

FILES:${PN} += " \
    /home/edge \
    /boot/firmware \
" 