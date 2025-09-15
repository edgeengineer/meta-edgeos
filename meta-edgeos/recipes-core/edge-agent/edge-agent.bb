SUMMARY = "EdgeOS Agent - Edge device management and control"
DESCRIPTION = "Downloads and manages the EdgeOS agent binary for device management"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://download-edge-agent.sh \
           file://edge-agent-updater.sh \
           file://edge-agent.service \
           file://edge-agent-updater.service \
           file://edge-agent-updater.timer"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "edge-agent.service edge-agent-updater.service edge-agent-updater.timer"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# Architecture mapping
def get_edge_agent_arch(d):
    target_arch = d.getVar('TARGET_ARCH')
    if target_arch == 'aarch64':
        return 'arm64'
    elif target_arch == 'x86_64':
        return 'amd64'
    elif target_arch.startswith('arm'):
        return 'arm'
    else:
        return target_arch

EDGE_AGENT_ARCH = "${@get_edge_agent_arch(d)}"
EDGE_AGENT_VERSION ?= "latest"
EDGE_AGENT_GITHUB_REPO = "edgeengineer/edge-agent"

# Try to download at build time if network is available
do_compile() {
    # Create a temporary download script for build-time use
    cat > ${B}/build-download.sh << 'EOF'
#!/bin/bash
set -e

GITHUB_REPO="${1}"
VERSION="${2}"
ARCH="${3}"
OUTPUT_FILE="${4}"

echo "Attempting to download edge-agent at build time..."
echo "Repository: ${GITHUB_REPO}"
echo "Version: ${VERSION}"
echo "Architecture: ${ARCH}"

# Determine the latest release if version is "latest"
if [ "${VERSION}" = "latest" ]; then
    API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
else
    API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${VERSION}"
fi

# Try to get release information
if command -v curl >/dev/null 2>&1; then
    RELEASE_INFO=$(curl -sL "${API_URL}" 2>/dev/null || echo "")
elif command -v wget >/dev/null 2>&1; then
    RELEASE_INFO=$(wget -qO- "${API_URL}" 2>/dev/null || echo "")
else
    echo "Neither curl nor wget available, skipping build-time download"
    exit 1
fi

if [ -z "${RELEASE_INFO}" ] || echo "${RELEASE_INFO}" | grep -q "Not Found"; then
    echo "Could not fetch release information, will download at runtime"
    exit 1
fi

# Parse download URL for the architecture
DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*edge-agent-linux-'${ARCH}'[^"]*"' | cut -d'"' -f4 | head -1)

if [ -z "${DOWNLOAD_URL}" ]; then
    # Try alternative naming patterns
    DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*edge-agent[^"]*linux[^"]*'${ARCH}'[^"]*"' | cut -d'"' -f4 | head -1)
fi

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "No suitable binary found for architecture: ${ARCH}"
    exit 1
fi

echo "Downloading from: ${DOWNLOAD_URL}"

# Download the file
if command -v curl >/dev/null 2>&1; then
    curl -L -o "${OUTPUT_FILE}.tmp" "${DOWNLOAD_URL}" || exit 1
else
    wget -O "${OUTPUT_FILE}.tmp" "${DOWNLOAD_URL}" || exit 1
fi

# Handle different file types
if echo "${DOWNLOAD_URL}" | grep -q '\.tar\.gz$'; then
    tar -xzf "${OUTPUT_FILE}.tmp" -O > "${OUTPUT_FILE}" 2>/dev/null || \
    tar -xzf "${OUTPUT_FILE}.tmp" edge-agent > "${OUTPUT_FILE}" 2>/dev/null || \
    tar -xzf "${OUTPUT_FILE}.tmp" --wildcards '*/edge-agent' --to-stdout > "${OUTPUT_FILE}" 2>/dev/null
    rm -f "${OUTPUT_FILE}.tmp"
elif echo "${DOWNLOAD_URL}" | grep -q '\.zip$'; then
    unzip -p "${OUTPUT_FILE}.tmp" edge-agent > "${OUTPUT_FILE}" 2>/dev/null || \
    unzip -p "${OUTPUT_FILE}.tmp" '*/edge-agent' > "${OUTPUT_FILE}" 2>/dev/null
    rm -f "${OUTPUT_FILE}.tmp"
else
    # Assume it's a binary
    mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
fi

if [ -f "${OUTPUT_FILE}" ] && [ -s "${OUTPUT_FILE}" ]; then
    chmod +x "${OUTPUT_FILE}"
    echo "Successfully downloaded edge-agent binary"
    exit 0
else
    echo "Download completed but binary not found or empty"
    exit 1
fi
EOF
    chmod +x ${B}/build-download.sh
    
    # Try to download at build time, but don't fail if it doesn't work
    if ${B}/build-download.sh "${EDGE_AGENT_GITHUB_REPO}" "${EDGE_AGENT_VERSION}" "${EDGE_AGENT_ARCH}" "${B}/edge-agent"; then
        echo "Edge-agent downloaded successfully at build time"
    else
        echo "Build-time download failed, will download at runtime"
    fi
}

do_install() {
    # Create necessary directories
    install -d ${D}/usr/local/bin
    install -d ${D}/opt/edgeos/bin
    install -d ${D}${systemd_system_unitdir}
    install -d ${D}/var/lib/edge-agent
    
    # Install the download script
    install -m 0755 ${WORKDIR}/download-edge-agent.sh ${D}/opt/edgeos/bin/
    
    # Install the updater script
    install -m 0755 ${WORKDIR}/edge-agent-updater.sh ${D}/opt/edgeos/bin/
    
    # If we downloaded the binary at build time, install it
    if [ -f ${B}/edge-agent ]; then
        install -m 0755 ${B}/edge-agent ${D}/usr/local/bin/edge-agent
        # Create a backup copy
        install -m 0755 ${B}/edge-agent ${D}/opt/edgeos/bin/edge-agent.backup
    else
        # Create a placeholder script that will download on first run
        cat > ${D}/usr/local/bin/edge-agent << 'EOF'
#!/bin/sh
echo "Edge-agent not yet installed, downloading..."
/opt/edgeos/bin/download-edge-agent.sh
if [ -f /usr/local/bin/edge-agent.real ]; then
    mv /usr/local/bin/edge-agent.real /usr/local/bin/edge-agent
    exec /usr/local/bin/edge-agent "$@"
else
    echo "Failed to download edge-agent"
    exit 1
fi
EOF
        chmod +x ${D}/usr/local/bin/edge-agent
    fi
    
    # Install systemd services
    install -m 0644 ${WORKDIR}/edge-agent.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edge-agent-updater.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edge-agent-updater.timer ${D}${systemd_system_unitdir}/
    
    # Pass configuration via environment file
    install -d ${D}${sysconfdir}/default
    cat > ${D}${sysconfdir}/default/edge-agent << EOF
# Edge Agent Configuration
EDGE_AGENT_GITHUB_REPO="${EDGE_AGENT_GITHUB_REPO}"
EDGE_AGENT_VERSION="${EDGE_AGENT_VERSION}"
EDGE_AGENT_ARCH="${EDGE_AGENT_ARCH}"
EOF
}

FILES:${PN} = "/usr/local/bin/* \
               /opt/edgeos/bin/* \
               ${systemd_system_unitdir}/* \
               ${sysconfdir}/default/edge-agent \
               /var/lib/edge-agent"

RDEPENDS:${PN} = "bash curl tar gzip jq"

# Allow network access during build (optional, for build-time download)
do_compile[network] = "1"