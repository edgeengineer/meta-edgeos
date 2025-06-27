#!/bin/bash
# EdgeOS USB Gadget Resume Script
# This script is triggered by udev when USB devices are detected

# Log to help with debugging
exec >> /tmp/usb-gadget-resume.log 2>&1
echo "$(date): USB gadget resume triggered"

# Function to check if NetworkManager is ready
is_networkmanager_ready() {
    # Check if NetworkManager is running and responsive
    systemctl is-active NetworkManager >/dev/null 2>&1 && \
    nmcli general status >/dev/null 2>&1
}

# Wait for USB override to complete (if running)
if [ -f /tmp/edgeos-usb-override-running ]; then
    echo "$(date): Waiting for USB override to complete..."
    timeout=30
    while [ -f /tmp/edgeos-usb-override-running ] && [ $timeout -gt 0 ]; do
        sleep 1
        timeout=$((timeout - 1))
    done
fi

# Check if USB override completed successfully
if [ ! -f /tmp/edgeos-usb-override-complete ]; then
    echo "$(date): USB override not complete, skipping resume"
    exit 0
fi

# Check if NetworkManager is ready
if ! is_networkmanager_ready; then
    echo "$(date): NetworkManager not ready, deferring network configuration"
    
    # Create a flag file that a later service can check
    touch /tmp/edgeos-usb-network-pending
    exit 0
fi

# Try to bring up NetworkManager connections if they exist
echo "$(date): NetworkManager ready, attempting to activate USB network connections..."

if nmcli connection show bridge-slave-usb0 >/dev/null 2>&1; then
    nmcli connection up bridge-slave-usb0 || echo "$(date): Failed to activate bridge-slave-usb0"
else
    echo "$(date): bridge-slave-usb0 connection not found"
fi

if nmcli connection show bridge-br0 >/dev/null 2>&1; then
    nmcli connection up bridge-br0 || echo "$(date): Failed to activate bridge-br0" 
else
    echo "$(date): bridge-br0 connection not found"
fi

# Remove pending flag if it exists
rm -f /tmp/edgeos-usb-network-pending

echo "$(date): USB gadget resume completed"