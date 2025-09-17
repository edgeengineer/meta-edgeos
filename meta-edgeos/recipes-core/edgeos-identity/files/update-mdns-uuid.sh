#!/bin/bash
# EdgeOS mDNS UUID Update Script
# Updates the Avahi service file with the device UUID

UUID_FILE="/etc/edgeos/device-uuid"
SERVICE_FILE="/etc/avahi/services/edgeos-mdns.service"

# Wait for UUID file to exist (in case of race condition)
for i in {1..10}; do
    if [ -f "$UUID_FILE" ]; then
        break
    fi
    sleep 1
done

if [ ! -f "$UUID_FILE" ]; then
    echo "Error: UUID file not found at $UUID_FILE"
    exit 1
fi

if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: Avahi service file not found at $SERVICE_FILE"
    exit 1
fi

# Read the UUID
UUID=$(cat "$UUID_FILE")

# Replace SOME_DEVICE_ID with actual UUID
sed -i "s/SOME_DEVICE_ID/$UUID/g" "$SERVICE_FILE"

echo "Updated mDNS service with device UUID: $UUID"
logger -t edgeos-identity "Updated mDNS service with UUID: $UUID"

# Reload Avahi to pick up changes if it's running
if systemctl is-active --quiet avahi-daemon; then
    avahi-daemon --reload || true
fi

exit 0