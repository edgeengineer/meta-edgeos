#!/bin/bash
#
# EdgeOS Agent Download Script
# Downloads the edge-agent binary from GitHub releases
#

set -e

# Load configuration
if [ -f /etc/default/edge-agent ]; then
    source /etc/default/edge-agent
fi

# Default values if not configured
GITHUB_REPO="${EDGE_AGENT_GITHUB_REPO:-edgeengineer/edge-agent}"
VERSION="${EDGE_AGENT_VERSION:-latest}"
ARCH="${EDGE_AGENT_ARCH:-arm64}"

# Paths
INSTALL_DIR="/usr/local/bin"
BACKUP_DIR="/opt/edgeos/bin"
BINARY_NAME="edge-agent"
TEMP_DIR="/tmp/edge-agent-download-$$"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    logger -t edge-agent-download "$*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

# Cleanup on exit
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    for tool in curl jq tar gzip; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log "Installing missing tools: ${missing_tools[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y ${missing_tools[*]}
        elif command -v opkg >/dev/null 2>&1; then
            opkg update && opkg install ${missing_tools[*]}
        else
            error "Missing required tools: ${missing_tools[*]}"
        fi
    fi
}

# Get release information from GitHub
get_release_info() {
    local api_url
    
    if [ "${VERSION}" = "latest" ]; then
        api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    else
        api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${VERSION}"
    fi
    
    log "Fetching release information from: ${api_url}"
    
    local release_info
    release_info=$(curl -sL "${api_url}" 2>/dev/null) || error "Failed to fetch release information"
    
    if echo "${release_info}" | grep -q '"message".*"Not Found"'; then
        error "Release ${VERSION} not found"
    fi
    
    echo "${release_info}"
}

# Download the binary
download_binary() {
    local release_info="$1"
    
    # Create temp directory
    mkdir -p "${TEMP_DIR}"
    
    # Look for the appropriate binary URL
    local download_url
    download_url=$(echo "${release_info}" | jq -r '.assets[] | select(.name | contains("linux")) | select(.name | contains("'${ARCH}'")) | .browser_download_url' | head -1)
    
    if [ -z "${download_url}" ] || [ "${download_url}" = "null" ]; then
        # Try alternative naming patterns
        download_url=$(echo "${release_info}" | jq -r '.assets[] | select(.name | contains("edge-agent")) | select(.name | contains("'${ARCH}'")) | .browser_download_url' | head -1)
    fi
    
    if [ -z "${download_url}" ] || [ "${download_url}" = "null" ]; then
        error "No suitable binary found for architecture: ${ARCH}"
    fi
    
    local filename=$(basename "${download_url}")
    log "Downloading: ${download_url}"
    
    curl -L -o "${TEMP_DIR}/${filename}" "${download_url}" || error "Download failed"
    
    # Extract if needed
    if [[ "${filename}" == *.tar.gz ]]; then
        log "Extracting tar.gz archive"
        tar -xzf "${TEMP_DIR}/${filename}" -C "${TEMP_DIR}"
        
        # Find the binary
        local binary_path
        binary_path=$(find "${TEMP_DIR}" -name "edge-agent" -type f | head -1)
        
        if [ -z "${binary_path}" ]; then
            error "Binary not found in archive"
        fi
        
        mv "${binary_path}" "${TEMP_DIR}/${BINARY_NAME}"
    elif [[ "${filename}" == *.zip ]]; then
        log "Extracting zip archive"
        unzip -q "${TEMP_DIR}/${filename}" -d "${TEMP_DIR}"
        
        # Find the binary
        local binary_path
        binary_path=$(find "${TEMP_DIR}" -name "edge-agent" -type f | head -1)
        
        if [ -z "${binary_path}" ]; then
            error "Binary not found in archive"
        fi
        
        mv "${binary_path}" "${TEMP_DIR}/${BINARY_NAME}"
    else
        # Assume it's the binary itself
        mv "${TEMP_DIR}/${filename}" "${TEMP_DIR}/${BINARY_NAME}"
    fi
    
    # Make executable
    chmod +x "${TEMP_DIR}/${BINARY_NAME}"
    
    # Verify it's a valid binary
    if ! file "${TEMP_DIR}/${BINARY_NAME}" | grep -q "executable"; then
        error "Downloaded file is not a valid executable"
    fi
    
    log "Binary downloaded and verified successfully"
}

# Install the binary
install_binary() {
    # Create directories if they don't exist
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${BACKUP_DIR}"
    
    # Backup existing binary if it exists
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        log "Backing up existing binary"
        cp "${INSTALL_DIR}/${BINARY_NAME}" "${BACKUP_DIR}/${BINARY_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Install new binary
    log "Installing new binary to ${INSTALL_DIR}/${BINARY_NAME}"
    mv "${TEMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}.real"
    
    # If there's a placeholder script, replace it
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ] && grep -q "Edge-agent not yet installed" "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null; then
        mv "${INSTALL_DIR}/${BINARY_NAME}.real" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        mv "${INSTALL_DIR}/${BINARY_NAME}.real" "${INSTALL_DIR}/${BINARY_NAME}"
    fi
    
    # Ensure proper permissions
    chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"
    
    # Keep a backup copy
    cp "${INSTALL_DIR}/${BINARY_NAME}" "${BACKUP_DIR}/${BINARY_NAME}.latest"
    
    log "Edge-agent installed successfully"
}

# Main execution
main() {
    log "Starting edge-agent download"
    log "Configuration: REPO=${GITHUB_REPO}, VERSION=${VERSION}, ARCH=${ARCH}"
    
    check_requirements
    
    local release_info
    release_info=$(get_release_info)
    
    download_binary "${release_info}"
    install_binary
    
    # Get version info if possible
    if "${INSTALL_DIR}/${BINARY_NAME}" --version >/dev/null 2>&1; then
        local installed_version=$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>&1 | head -1)
        log "Installed version: ${installed_version}"
    fi
    
    log "Edge-agent download completed successfully"
}

# Run main function
main "$@"