SUMMARY = "EdgeOS Agent"
DESCRIPTION = "Downloads and installs the EdgeOS edge-agent binary"
LICENSE = "CLOSED"

SRC_URI = "file://edge-agent.service \
           file://edge-agent-running.service \
           file://edge-agent-updater.sh"

S = "${WORKDIR}"

RDEPENDS:${PN} = " \
    curl \
    wget \
    bash \
    systemd \
    ca-certificates \
    coreutils \
    findutils \
    file \
    tar \
    gzip \
    iputils-ping \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "edge-agent.service edge-agent-running.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edge-agent.service ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edge-agent-running.service ${D}${systemd_system_unitdir}
    
    # Create EdgeOS directories
    install -d ${D}/opt/edgeos/bin
    
    # Install updater script
    install -m 0755 ${WORKDIR}/edge-agent-updater.sh ${D}/opt/edgeos/bin/
}

# Note: Edge agent will be downloaded by the updater script at runtime
# This keeps the build process simpler and more reliable

FILES:${PN} += "/opt/edgeos/bin/*" 