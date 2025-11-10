#!/bin/bash

### 
### place this in /usr/local/sbin/usb-gadget.sh to run at boot
###

###### Functions ######

### Logging
# Debug output with proper logging levels
exec 1> >(logger -s -t "$(basename "$0")") 2> >(logger -s -t "$(basename "$0")" -p daemon.err)

# Helper functions for logging
log_info() {
    logger -s -t "$(basename "$0")" -p daemon.info "$1"
}

log_warning() {
    logger -s -t "$(basename "$0")" -p daemon.warning "$1"
}

log_error() {
    logger -s -t "$(basename "$0")" -p daemon.err "$1"
}

# Function to generate a MAC address from a string
# uses "Locally Administered Addresses"
# This means the second character of the first octet should be 2, 6, A, or E (in hexadecimal).
generate_mac() {
    local input="$1"
    # Generate a SHA-256 hash of the input using sha256sum instead of shasum
    local hash=$(echo -n "$input" | sha256sum | awk '{print $1}')
    
    # Take the first 12 characters of the hash
    local mac_base=${hash:0:12}
    
    # Ensure the address is locally administered by setting the second character to 2, 6, A, or E
    local first_byte=${mac_base:0:2}
    local second_char=$(printf '%x' $((0x$first_byte & 0xfe | 0x02)))
    
    # Construct the MAC address
    printf "%02x:%02x:%02x:%02x:%02x:%02x" \
       0x$second_char \
       0x${mac_base:2:2} \
       0x${mac_base:4:2} \
       0x${mac_base:6:2} \
       0x${mac_base:8:2} \
       0x${mac_base:10:2}
}

### Check if this is a Raspberry Pi 5
IS_PI5=false
if [ -f /proc/device-tree/model ]; then
    PI_MODEL=$(cat /proc/device-tree/model | tr -d '\0')
    if [[ "$PI_MODEL" == *"Raspberry Pi 5"* ]]; then
        IS_PI5=true
        log_info "Detected Raspberry Pi 5: $PI_MODEL"
    else
        log_info "Detected non-Pi 5 device: $PI_MODEL"
    fi
else
    log_info "Could not detect Raspberry Pi model"
fi

### eeprom patch
if [ "$IS_PI5" = true ]; then
    log_info "Performing EEPROM patch for Raspberry Pi 5"
    
    # Find the RPi5 EEPROM binary
    FIRMWARE_DIR="/lib/firmware/raspberrypi/bootloader-2712"
    FIRMWARE_PATH=""

    if [ -d "${FIRMWARE_DIR}/default" ]; then
        FIRMWARE_PATH=$(find "${FIRMWARE_DIR}/default" -name 'pieeprom-*.bin' -print -quit)
    fi

    if [ -z "$FIRMWARE_PATH" ] && [ -d "${FIRMWARE_DIR}/stable" ]; then
        FIRMWARE_PATH=$(find "${FIRMWARE_DIR}/stable" -name 'pieeprom-*.bin' -print -quit)
    fi

    if [ -z "$FIRMWARE_PATH" ]; then
        echo "ERROR: Could not find RPi5 EEPROM firmware binary" >&2
        exit 1
    fi

    # Check current setting first
    CURRENT_CONFIG=$(rpi-eeprom-config)
    CURRENT_PSU_CURRENT=$(echo "$CURRENT_CONFIG" | grep "^PSU_MAX_CURRENT=" | cut -d'=' -f2)

    echo "Current PSU_MAX_CURRENT=$CURRENT_PSU_CURRENT"

    if [ "$CURRENT_PSU_CURRENT" != "3000" ]; then
        echo "Current PSU_MAX_CURRENT=$CURRENT_PSU_CURRENT, updating to 3000mA..."

        # Create temporary workspace
        TMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TMP_DIR"' EXIT

        # Extract current config
        if ! rpi-eeprom-config "${FIRMWARE_PATH}" --out "${TMP_DIR}/bootconf.txt"; then
            echo "ERROR: Failed to extract EEPROM config" >&2
            exit 1
        fi

        # Set PSU_MAX_CURRENT=3000
        sed -i '/^PSU_MAX_CURRENT=/d' "${TMP_DIR}/bootconf.txt"
        echo "PSU_MAX_CURRENT=3000" >> "${TMP_DIR}/bootconf.txt"

        # Create new firmware binary
        if ! rpi-eeprom-config "${FIRMWARE_PATH}" --config "${TMP_DIR}/bootconf.txt" --out "${TMP_DIR}/pieeprom-new.bin"; then
            echo "ERROR: Failed to create new EEPROM binary" >&2
            exit 1
        fi

        # Stage for update on first boot
        if ! rpi-eeprom-update -d -f "${TMP_DIR}/pieeprom-new.bin"; then
            echo "ERROR: Failed to stage new EEPROM binary for update" >&2
            exit 1
        fi

        echo "EEPROM configuration successfully staged for first boot"
        sudo reboot
    fi
else
    log_info "Skipping EEPROM patch as this is not a Raspberry Pi 5"
fi

### End of Functions ######

### Config Variables ######

## TODO: we need a variable to split which device this is for.

# Get serial number based on device type
PI_SERIAL=""

# First try device tree serial (NVIDIA/modern approach)
if [ -f /proc/device-tree/serial-number ]; then
    PI_SERIAL=$(cat /proc/device-tree/serial-number 2>/dev/null | tr -d '\0')
fi

# If device tree method didn't work, try Raspberry Pi method
if [ -z "$PI_SERIAL" ] && [ -f /proc/cpuinfo ]; then
    PI_SERIAL=$(awk -F ': ' '/Serial/ {print $2}' /proc/cpuinfo 2>/dev/null)
fi

# If Pi method didn't work, try Jetson methods
if [ -z "$PI_SERIAL" ]; then
    # Try Tegra SoC UID first
    PI_SERIAL=$(cat /sys/devices/platform/tegra-fuse/uid 2>/dev/null)
fi

if [ -z "$PI_SERIAL" ]; then
    # Try Tegra chip ID
    PI_SERIAL=$(cat /sys/module/tegra_fuse/parameters/tegra_chip_id 2>/dev/null)
fi

if [ -z "$PI_SERIAL" ]; then
    # Try board serial
    PI_SERIAL=$(tegra-boardid 2>/dev/null | grep -o "Serial.*" | cut -d' ' -f2)
fi

# If all else fails, use MAC address
if [ -z "$PI_SERIAL" ]; then
    PI_SERIAL=$(cat /sys/class/net/eth0/address 2>/dev/null || echo "UNKNOWN")
fi

# Ensure we have a valid serial (fallback to timestamp if all methods fail)
if [ -z "$PI_SERIAL" ] || [ "$PI_SERIAL" = "UNKNOWN" ]; then
    PI_SERIAL="$(date +%s)"
fi

# Get last 8 characters of serial for a shorter identifier
SHORT_SERIAL=${PI_SERIAL: -8}

# Remove colons from SHORT_SERIAL for product name (fallback)
CLEAN_SERIAL=$(echo $SHORT_SERIAL | tr -d ':')

# Try to read the 2-word device name first
DEVICE_NAME_FILE="/etc/edgeos/device-name"
if [ -f "$DEVICE_NAME_FILE" ]; then
    DEVICE_FRIENDLY_NAME=$(cat "$DEVICE_NAME_FILE" | tr -d '[:space:]')
    log_info "Using device name from $DEVICE_NAME_FILE: $DEVICE_FRIENDLY_NAME"
else
    # Fallback to serial-based name if device name not available
    DEVICE_FRIENDLY_NAME="${CLEAN_SERIAL}"
    log_warning "Device name file not found, using serial: $DEVICE_FRIENDLY_NAME"
fi

# Variables for device identification
GADGET_NAME="edgeos_device"
MANUFACTURER="Wendy Labs Inc"
PRODUCT="WendyOS Device ${DEVICE_FRIENDLY_NAME}"

### End of Config Variables ######

# Define gadget dir
GADGET_DIR="/sys/kernel/config/usb_gadget/$(echo $GADGET_NAME)"
mkdir -p $GADGET_DIR
cd $GADGET_DIR

### Configure USB Gadget

# Set vendor and product
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget

echo 0x0100 > bcdDevice # v1.0.3

# Detect USB controller type and set appropriate USB version
USB_VERSION="0x0200"  # Default to USB 2.0
USB_CONTROLLER="unknown"

# Check if dwc3 (USB 3.x) is available
if lsmod | grep -q "dwc3" || find /sys/class/udc -name "*dwc3*" -type l 2>/dev/null | grep -q dwc3; then
    USB_VERSION="0x0300"  # USB 3.0
    USB_CONTROLLER="dwc3"
    log_info "Detected dwc3 controller - setting USB 3.1 mode"
elif lsmod | grep -q "dwc2" || find /sys/class/udc -name "*dwc2*" -type l 2>/dev/null | grep -q dwc2; then
    USB_VERSION="0x0200"  # USB 2.0
    USB_CONTROLLER="dwc2"
    log_info "Detected dwc2 controller - setting USB 2.0 mode"
elif lsmod | grep -q "tegra_xudc" || find /sys/class/udc -name "*tegra*" -type l 2>/dev/null | grep -q tegra; then
    USB_VERSION="0x0300"  # USB 3.0 (Jetson supports USB 3)
    USB_CONTROLLER="tegra-xudc"
    log_info "Detected tegra-xudc controller - setting USB 3.0 mode"
else
    log_info "No specific USB controller detected - defaulting to USB 2.0 mode"
fi

echo $USB_VERSION > bcdUSB
log_info "USB controller: $USB_CONTROLLER, USB version: $USB_VERSION (High Speed gadget mode)"

# Create configuration directory first
mkdir -p configs/c.1/strings/0x409

# Set power configuration based on device type
if [ "$USB_CONTROLLER" = "dwc3" ]; then
    # Jetson (dwc3) - externally powered device
    echo 0xC0 > configs/c.1/bmAttributes  # Self-powered with remote wakeup
    
    log_info "Configured as self-powered device (externally powered)"
    echo 0xEF > bDeviceClass
    echo 0x02 > bDeviceSubClass
    echo 0x01 > bDeviceProtocol
else
    # Pi (dwc2) - may be bus-powered or externally powered
    echo 2 > bDeviceClass  # Composite device class (correct)
    echo 0x80 > configs/c.1/bmAttributes  # Bus-powered  
    echo 250 > configs/c.1/MaxPower      # 500mA for Pi power needs
    log_info "Configured as bus-powered device (may draw USB power)"
fi

# Set English strings
mkdir -p strings/0x409
echo $PI_SERIAL > strings/0x409/serialnumber
echo $MANUFACTURER > strings/0x409/manufacturer
echo $PRODUCT > strings/0x409/product

# Build dynamic configuration string (inspired by NVIDIA approach)
CFG_STR="CDC+ACM"  # We're using NCM (network) and ACM (serial) functions

# This string is what the USB host sees when it enumerates the device's configurations
# (for example, in tools like lsusb or Windows Device Manager).
echo "${CFG_STR}" > configs/c.1/strings/0x409/configuration

# Generate MAC addresses
log_info "Generating MAC addresses with serial: $PI_SERIAL"

# Generate different MACs for each interface
hash_host_ncm=$(echo -n "${PI_SERIAL}-host-ncm" | md5sum | awk '{print $1}')
hash_self_ncm=$(echo -n "${PI_SERIAL}-self-ncm" | md5sum | awk '{print $1}')

# Generate MAC addresses
mac_address_host_ncm=$(generate_mac "$hash_host_ncm")
mac_address_self_ncm=$(generate_mac "$hash_self_ncm")

log_info "Generated MAC Address for host_ncm: $mac_address_host_ncm"
log_info "Generated MAC Address for self_ncm: $mac_address_self_ncm"

# NCM - create network configuration
mkdir -p functions/ncm.usb0
echo $mac_address_host_ncm > functions/ncm.usb0/host_addr
echo $mac_address_self_ncm > functions/ncm.usb0/dev_addr

# Set qmult for better throughput (increases USB transfer efficiency)
# Default is 5, we increase to 10 for ~2x better performance
echo 10 > functions/ncm.usb0/qmult
log_info "NCM qmult set to 10 for optimized throughput"

ln -s functions/ncm.usb0 configs/c.1/

# ACM - create serial console (creates /dev/ttyGS0)
log_info "Creating ACM serial gadget function"
mkdir -p functions/acm.usb0
ln -s functions/acm.usb0 configs/c.1/
log_info "ACM serial function configured (will create /dev/ttyGS0)"

# Robust UDC detection with timeout (inspired by NVIDIA approach)
UDC=""
UDC_TIMEOUT=60

log_info "Searching for UDC device..."
for i in $(seq $UDC_TIMEOUT); do
    # Look for any available UDC device
    if [ -d "/sys/class/udc" ]; then
        UDC=$(ls /sys/class/udc 2>/dev/null | head -n 1)
        if [ -n "$UDC" ] && [ -e "/sys/class/udc/$UDC" ]; then
            log_info "Found UDC device: $UDC"
            break
        fi
    fi
    
    if [ $i -eq $UDC_TIMEOUT ]; then
        log_error "UDC device detection timeout after ${UDC_TIMEOUT} seconds"
        exit 1
    fi
    
    sleep 1
done

if [ -z "$UDC" ]; then
    log_error "No UDC device found"
    exit 1
fi

# Ensure clean state before activation
# Only clear UDC if it's already set (avoid "No such device" error on first boot)
if [ -f UDC ] && [ -s UDC ]; then
    echo "" > UDC 2>/dev/null || log_info "UDC already cleared"
    sleep 1
fi
echo "$UDC" > UDC
log_info "UDC device activated: $UDC"

# Wait for USB device to be fully initialized
udevadm settle -t 20
log_info "USB gadget device initialized"

# Check and disable dnsmasq if it's enabled
if systemctl is-enabled dnsmasq >/dev/null 2>&1; then
    log_info "Disabling system dnsmasq service..."
    systemctl disable dnsmasq
else
    log_info "System dnsmasq service is already disabled"
fi

# Configure usb0 directly with NetworkManager (no bridge needed)
log_info "Configuring usb0 network interface"

# Check if usb0 connection exists, create/update it
if ! nmcli connection show | grep -q "usb0-edgeos"; then
    log_info "Creating usb0-edgeos connection"
    nmcli connection add type ethernet \
        con-name usb0-edgeos \
        ifname usb0 \
        ipv4.method shared \
        ipv4.addresses 10.42.0.1/24
    log_info "usb0-edgeos connection created"
else
    log_info "usb0-edgeos connection already exists, updating configuration"
    nmcli connection modify usb0-edgeos \
        ipv4.method shared \
        ipv4.addresses 10.42.0.1/24
fi

# Bring up usb0 connection with retry logic
for i in {1..3}; do
    nmcli connection up usb0-edgeos && break
    log_info "Retry $i: Bringing up usb0-edgeos"
    sleep 2
done

# Optimize network interface settings for high throughput
log_info "Applying network interface optimizations..."

# Set TX queue length for better burst handling
ip link set usb0 txqueuelen 2000 2>/dev/null && log_info "Set usb0 TX queue to 2000" || log_warn "Could not set usb0 TX queue"

# Optimize USB IRQ affinity (pin to CPUs 0-3 for better cache locality)
USB_IRQ=$(grep "3550000.usb" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ')
if [ -n "$USB_IRQ" ]; then
    echo "0f" > /proc/irq/$USB_IRQ/smp_affinity 2>/dev/null && \
        log_info "USB IRQ $USB_IRQ pinned to CPUs 0-3" || \
        log_warn "Could not set USB IRQ affinity"
else
    log_info "USB IRQ not found yet, will be optimized by sysctl"
fi

log_info "Network interface optimizations complete"