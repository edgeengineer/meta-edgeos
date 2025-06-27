#!/bin/bash
# EdgeOS USB Override - Clean up NVIDIA USB gadget and prepare for EdgeOS setup
# Keeps tegra-xudc driver, just reconfigures the gadget

# Add better error handling and logging
# exec 2>&1
# set -x  # Enable debug output

echo "EdgeOS: Taking control of USB gadget configuration"

# Step 1: Tear down NVIDIA's network interface before gadget cleanup
if [ -d "/sys/kernel/config/usb_gadget/l4t" ]; then
    echo "EdgeOS: Found NVIDIA USB gadget, cleaning up network interface"
    
    # Get NVIDIA's RNDIS interface name before teardown
    NVIDIA_IFACE=""
    if [ -f "/sys/kernel/config/usb_gadget/l4t/functions/rndis.usb0/ifname" ]; then
        NVIDIA_IFACE=$(cat /sys/kernel/config/usb_gadget/l4t/functions/rndis.usb0/ifname 2>/dev/null)
        echo "EdgeOS: Found NVIDIA RNDIS interface: $NVIDIA_IFACE"
        
        # Tear down the network interface properly
        echo "EdgeOS: Tearing down NVIDIA network interface: $NVIDIA_IFACE"
        ip addr flush dev "$NVIDIA_IFACE" 2>/dev/null || echo "EdgeOS: Warning - Could not flush addresses"
        ip link set "$NVIDIA_IFACE" down 2>/dev/null || echo "EdgeOS: Warning - Could not bring down interface"
        
        # Remove from NetworkManager if available
        if command -v nmcli >/dev/null 2>&1; then
            nmcli device set "$NVIDIA_IFACE" managed no 2>/dev/null || true
        fi
    fi
    
    # Step 2: Clean up NVIDIA's USB gadget configuration
    echo "EdgeOS: Cleaning up NVIDIA USB gadget configuration"
    cd /sys/kernel/config/usb_gadget/l4t || {
        echo "EdgeOS: Error - Could not access gadget directory"
        exit 1
    }
    
    # Deactivate the gadget first
    if [ -f "UDC" ]; then
        echo "EdgeOS: Deactivating USB Device Controller"
        echo "" > UDC 2>/dev/null || {
            echo "EdgeOS: Error - Failed to deactivate UDC"
            exit 1
        }
    fi
    
    # Remove configuration links and functions in proper order
    echo "EdgeOS: Removing gadget configuration"
    for config in configs/*/; do
        if [ -d "$config" ]; then
            # Remove function links
            find "$config" -type l -delete 2>/dev/null || true
            # Remove config strings
            rm -rf "$config/strings" 2>/dev/null || true
        fi
    done
    
    # Remove function directories
    rm -rf functions/* 2>/dev/null || true
    rm -rf configs/* 2>/dev/null || true
    
    # Remove gadget strings and os_desc
    find strings -type f -delete 2>/dev/null || true
    find strings -mindepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
    find os_desc -type f -delete 2>/dev/null || true
    rmdir os_desc 2>/dev/null || true
    
    # Remove the gadget directory
    cd /
    if rmdir /sys/kernel/config/usb_gadget/l4t 2>/dev/null; then
        echo "EdgeOS: NVIDIA USB gadget successfully removed"
    else
        echo "EdgeOS: Warning - Could not remove gadget directory, forcing cleanup"
        # Force cleanup for stubborn entries
        cd /sys/kernel/config/usb_gadget/l4t
        find . -type l -delete 2>/dev/null || true
        find . -type f -delete 2>/dev/null || true
        find . -mindepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
        cd /
        rmdir /sys/kernel/config/usb_gadget/l4t 2>/dev/null || echo "EdgeOS: Warning - Gadget directory cleanup failed"
    fi
else
    echo "EdgeOS: No NVIDIA USB gadget found, skipping cleanup"
fi

# Step 3: Load USB gadget framework modules (keeping tegra-xudc as driver)
echo "EdgeOS: Loading USB gadget framework modules"

# Function to safely load module if available
load_module_if_available() {
    local module="$1"
    if modinfo "$module" >/dev/null 2>&1; then
        if ! lsmod | grep -q "^$module "; then
            echo "EdgeOS: Loading module: $module"
            modprobe "$module" || echo "EdgeOS: Warning - failed to load $module"
        else
            echo "EdgeOS: Module $module already loaded"
        fi
    else
        echo "EdgeOS: Module $module not available as loadable module (may be built-in)"
    fi
}

# Load USB gadget framework and function modules
load_module_if_available "libcomposite"
load_module_if_available "usb_f_rndis"
load_module_if_available "usb_f_ncm"
load_module_if_available "usb_f_acm"
load_module_if_available "usb_f_mass_storage"
load_module_if_available "u_ether"
load_module_if_available "u_serial"

# Step 4: Verify USB Device Controller is available (tegra-xudc)
echo "EdgeOS: Verifying USB Device Controller availability"
if ls /sys/class/udc/ 2>/dev/null | grep -q .; then
    UDC_NAME=$(ls /sys/class/udc/ | head -1)
    echo "EdgeOS: USB Device Controller available: $UDC_NAME"
else
    echo "EdgeOS: Warning - No USB Device Controller found"
fi

# Step 5: Set USB role to device mode (if role switching is available)
echo "EdgeOS: Setting USB role to device mode"
role_switches_found=0
for role_switch in /sys/class/usb_role/*/role; do
    if [ -f "$role_switch" ]; then
        role_switches_found=$((role_switches_found + 1))
        role_switch_name=$(basename "$(dirname "$role_switch")")
        echo "EdgeOS: Setting $role_switch_name to device mode"
        if echo "device" > "$role_switch" 2>/dev/null; then
            echo "EdgeOS: Successfully set $role_switch_name to device mode"
        else
            echo "EdgeOS: Warning - Could not set $role_switch_name to device mode"
        fi
    fi
done

if [ "$role_switches_found" -eq 0 ]; then
    echo "EdgeOS: No USB role switches found (normal for some configurations)"
else
    echo "EdgeOS: Processed $role_switches_found USB role switches"
fi

# Step 6: Verify system is ready for EdgeOS USB gadget setup
echo "EdgeOS: Verifying system readiness"
if lsmod | grep -q libcomposite; then
    echo "EdgeOS: ✓ USB gadget framework loaded"
else
    echo "EdgeOS: ✗ USB gadget framework not loaded"
fi

if [ -d "/sys/kernel/config/usb_gadget" ]; then
    echo "EdgeOS: ✓ USB gadget ConfigFS available"
else
    echo "EdgeOS: ✗ USB gadget ConfigFS not available"
fi

if ls /sys/class/udc/ >/dev/null 2>&1; then
    echo "EdgeOS: ✓ USB Device Controller available"
else
    echo "EdgeOS: ✗ USB Device Controller not available"
fi

# Step 7: Create flag file to indicate override is complete
touch /tmp/edgeos-usb-override-complete
echo "EdgeOS: USB override completed successfully - ready for EdgeOS USB gadget setup"

# Optional: Display summary
echo "EdgeOS: Summary:"
echo "  - USB Controller: tegra-xudc (kept as-is)"
echo "  - NVIDIA gadget: removed"
echo "  - Network interface: cleaned up"
echo "  - USB gadget modules: loaded"
echo "  - Ready for: edgeos-usbgadget-init.sh"