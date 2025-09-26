DESCRIPTION = "EdgeOS container runtime support"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

# Container runtime packages and their dependencies
# Note: kernel-module-* packages ensure the modules are included in the image
# and available at runtime, even if they're built as modules (=m) in kernel config
# Runtime dependencies - core container packages
RDEPENDS:${PN} = " \
    containerd-opencontainers \
    runc-opencontainers \
    cni \
    cni-config \
    iptables \
    iptables-modules \
    ca-certificates \
    ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'systemd-container', '', d)} \
    "

# Essential kernel modules for basic container operation
# We use RRECOMMENDS since these might be built into the kernel
RRECOMMENDS:${PN} = " \
    kernel-module-overlay \
    kernel-module-bridge \
    kernel-module-br-netfilter \
    kernel-module-veth \
    kernel-module-xt-nat \
    kernel-module-xt-masquerade \
    kernel-module-xt-conntrack \
    kernel-module-xt-addrtype \
    kernel-module-nf-nat \
    kernel-module-nf-conntrack \
    kernel-module-ip-tables \
    "

# Optional: Add docker if needed (heavier than containerd alone)
# RDEPENDS:${PN} += "docker-ce"

# Optional: Add nerdctl for easier container management
# nerdctl is a Docker-compatible CLI for containerd
# RDEPENDS:${PN} += "nerdctl"