#!/bin/bash

# Directory where the edge-agent binary will be stored
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="edge-agent"
FULL_PATH="${INSTALL_DIR}/${BINARY_NAME}"
BACKUP_PATH="/opt/edgeos/bin/${BINARY_NAME}"

# Make sure we have the directories
mkdir -p "${INSTALL_DIR}"
mkdir -p "/opt/edgeos/bin"

# Log file for debugging
LOG_FILE="/var/log/edge-agent-update.log"

echo "$(date): Starting edge-agent updater" >> "${LOG_FILE}"

# Check internet connectivity
if ping -c 1 github.com >/dev/null 2>&1; then
    echo "$(date): Internet connection available, attempting to download latest version" >> "${LOG_FILE}"
    
    # Create a temporary directory
    TMP_DIR=$(mktemp -d)
    cd "${TMP_DIR}"
    
    # Get all releases including pre-releases
    echo "$(date): Fetching all releases..." >> "${LOG_FILE}"
    if ! curl -s "https://api.github.com/repos/apache-edge/edge-agent/releases" > releases.json; then
        echo "$(date): Failed to fetch releases" >> "${LOG_FILE}"
    else
        # Parse the JSON to find the latest pre-release
        DOWNLOAD_URL=$(cat releases.json | 
                      grep -o '"browser_download_url": *"[^"]*edge-agent[^"]*"' | 
                      head -n 1 | 
                      awk -F'"' '{print $4}')

        if [ -z "$DOWNLOAD_URL" ]; then
            echo "$(date): No edge-agent downloads found in releases" >> "${LOG_FILE}"
        else
            echo "$(date): Found download URL: $DOWNLOAD_URL" >> "${LOG_FILE}"
            
            # Download the latest version
            if wget -q "$DOWNLOAD_URL"; then
                # Find the downloaded file
                DOWNLOADED_FILE=$(find . -type f -name "*edge-agent*" | head -n 1)
                
                if [ -n "${DOWNLOADED_FILE}" ]; then
                    echo "$(date): Downloaded new version: ${DOWNLOADED_FILE}" >> "${LOG_FILE}"
                    
                    # Extract if it's a tar.gz file
                    if file "${DOWNLOADED_FILE}" | grep -q "gzip compressed data"; then
                        echo "$(date): Extracting tar.gz file..." >> "${LOG_FILE}"
                        mkdir -p "${TMP_DIR}/extract"
                        tar -xzf "${DOWNLOADED_FILE}" -C "${TMP_DIR}/extract"
                        
                        # Find the binary in the extracted directory
                        EXTRACTED_BINARY=$(find "${TMP_DIR}/extract" -type f -name "edge-agent" | head -n 1)
                        
                        if [ -n "${EXTRACTED_BINARY}" ]; then
                            chmod +x "${EXTRACTED_BINARY}"
                            BINARY_PATH="${EXTRACTED_BINARY}"
                        else
                            echo "$(date): Could not find edge-agent binary in the extracted archive" >> "${LOG_FILE}"
                            cd /
                            rm -rf "${TMP_DIR}"
                            exit 1
                        fi
                    else
                        # Make it executable if it's already a binary
                        chmod +x "${DOWNLOADED_FILE}"
                        BINARY_PATH="${DOWNLOADED_FILE}"
                    fi
                    
                    # Move it to the install directory
                    cp "${BINARY_PATH}" "${FULL_PATH}"
                    
                    # Also update the backup
                    cp "${BINARY_PATH}" "${BACKUP_PATH}"
                    
                    echo "$(date): Successfully installed new version of edge-agent" >> "${LOG_FILE}"
                else
                    echo "$(date): Download succeeded but couldn't find the binary" >> "${LOG_FILE}"
                fi
            else
                echo "$(date): Failed to download from $DOWNLOAD_URL" >> "${LOG_FILE}"
            fi
        fi
    fi
    
    # Clean up
    cd /
    rm -rf "${TMP_DIR}"
else
    echo "$(date): No internet connection available" >> "${LOG_FILE}"
fi

# If we don't have the binary in the install location but have a backup, use that
if [ ! -f "${FULL_PATH}" ] && [ -f "${BACKUP_PATH}" ]; then
    echo "$(date): Using backup edge-agent from ${BACKUP_PATH}" >> "${LOG_FILE}"
    cp "${BACKUP_PATH}" "${FULL_PATH}"
    chmod +x "${FULL_PATH}"
fi

# Make sure the binary is executable
if [ -f "${FULL_PATH}" ]; then
    chmod +x "${FULL_PATH}"
    echo "$(date): edge-agent is installed and executable" >> "${LOG_FILE}"
else
    echo "$(date): WARNING: edge-agent is not installed" >> "${LOG_FILE}"
fi

exit 0 