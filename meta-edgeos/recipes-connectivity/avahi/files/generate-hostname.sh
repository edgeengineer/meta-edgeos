#!/bin/bash
#
# EdgeOS Hostname Generation Script
# Generates a unique hostname based on device serial number
#

set -e

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    logger -t edgeos-hostname "$*"
}

# Get device serial number or unique identifier
get_device_id() {
    local device_id=""
    
    # Try to get Raspberry Pi serial
    if [ -f /proc/cpuinfo ]; then
        device_id=$(grep Serial /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | tr -d ' ' || true)
    fi
    
    # If no serial found, try machine-id
    if [ -z "${device_id}" ] && [ -f /etc/machine-id ]; then
        device_id=$(cat /etc/machine-id | head -c 16)
    fi
    
    # If still no ID, generate one
    if [ -z "${device_id}" ]; then
        device_id=$(ip link show | grep ether | head -1 | awk '{print $2}' | tr -d ':' | head -c 16)
    fi
    
    # Fallback to random
    if [ -z "${device_id}" ]; then
        device_id=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)
    fi
    
    echo "${device_id}"
}

# Generate hostname
generate_hostname() {
    local device_id=$(get_device_id)
    
    # Take last 8 characters for readability
    local short_id="${device_id: -8}"
    
    # Convert to lowercase
    short_id=$(echo "${short_id}" | tr '[:upper:]' '[:lower:]')
    
    # Create hostname
    local hostname="edgeos-${short_id}"
    
    echo "${hostname}"
}

# Set hostname
set_hostname() {
    local new_hostname="$1"
    local current_hostname=$(hostname)
    
    if [ "${current_hostname}" = "${new_hostname}" ]; then
        log "Hostname already set to ${new_hostname}"
        return 0
    fi
    
    log "Setting hostname to ${new_hostname}"
    
    # Set hostname using hostnamectl if available
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "${new_hostname}"
    else
        # Fallback to traditional method
        echo "${new_hostname}" > /etc/hostname
        hostname "${new_hostname}"
    fi
    
    # Update /etc/hosts
    if ! grep -q "${new_hostname}" /etc/hosts; then
        # Remove old edgeos entries
        sed -i '/edgeos-/d' /etc/hosts
        
        # Add new entry
        echo "127.0.1.1 ${new_hostname} ${new_hostname}.local" >> /etc/hosts
    fi
    
    log "Hostname set successfully to ${new_hostname}"
}

# Main execution
main() {
    log "Starting EdgeOS hostname generation"
    
    # Check if we should skip (for development or custom setups)
    if [ -f /etc/edgeos-hostname-override ]; then
        log "Hostname override found, skipping automatic generation"
        exit 0
    fi
    
    # Generate and set hostname
    local hostname=$(generate_hostname)
    set_hostname "${hostname}"
    
    # Store the generated hostname for reference
    echo "${hostname}" > /etc/edgeos-hostname
    
    # Restart avahi-daemon if it's running to pick up new hostname
    if systemctl is-active --quiet avahi-daemon.service; then
        log "Restarting avahi-daemon to pick up new hostname"
        systemctl restart avahi-daemon.service
    fi
    
    log "EdgeOS hostname generation completed"
}

# Run main function
main "$@"