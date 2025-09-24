DESCRIPTION = "EdgeOS container runtime support"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

RDEPENDS:${PN} = " \
    containerd \
    containerd-ctr \
    runc \
    cni \
    cni-plugins \
    iptables \
    iptables-modules \
    kernel-module-xt-nat \
    kernel-module-xt-masquerade \
    kernel-module-xt-conntrack \
    kernel-module-xt-addrtype \
    kernel-module-br-netfilter \
    kernel-module-overlay \
    ca-certificates \
    "

# Optional: Add docker if needed (heavier than containerd alone)
# RDEPENDS:${PN} += "docker-ce"