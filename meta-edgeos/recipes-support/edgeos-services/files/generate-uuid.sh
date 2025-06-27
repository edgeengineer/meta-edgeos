#!/bin/bash

UUID_FILE="/etc/edgeos/device-uuid"

# Only generate UUID if it doesn't exist
if [ ! -f "$UUID_FILE" ]; then
    # Try primary method first
    if [ -f "/proc/sys/kernel/random/uuid" ]; then
        NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    else
        # Fallback to uuidgen
        NEW_UUID=$(uuidgen)
    fi
    
    # Verify we got a valid UUID
    if [[ ! $NEW_UUID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
        echo "Failed to generate valid UUID"
        exit 1
    fi
    
    # Write UUID to protected file
    echo "$NEW_UUID" > "$UUID_FILE"
    
    # Set proper permissions (only root can read/write)
    chmod 600 "$UUID_FILE"
    chown root:root "$UUID_FILE"
fi