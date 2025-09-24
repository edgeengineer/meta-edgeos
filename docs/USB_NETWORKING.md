# USB Networking Features

This document describes the USB networking improvements added to EdgeOS for reliable host-device communication over USB.

## Overview

EdgeOS devices connect to host computers via USB using the NCM (Network Control Model) protocol, creating a virtual Ethernet interface. Recent improvements ensure reliable IPv6 connectivity and prevent MAC address conflicts between multiple devices.

## Features

### 1. Dynamic MAC Address Generation (EDG-290)

**Problem**: Previously used hardcoded MAC addresses caused conflicts when multiple EdgeOS devices were connected to the same host.

**Solution**: MAC addresses are now dynamically generated based on the device's unique serial number.

#### Implementation
- Location: `/usr/libexec/edgeos-generate-mac`
- Method: SHA256 hash of device serial + interface name, with locally administered bit set
- Result: Deterministic, unique MAC addresses per device

#### Generated MACs
- Device MAC: `ee:b5:ad:79:79:c5` (example, varies by device serial)
- Host MAC: `ea:b5:ad:79:79:c6` (example, varies by device serial)

### 2. IPv6 Router Advertisement (EDG-291)

**Problem**: Host computers couldn't establish IPv6 connectivity with EdgeOS devices over USB.

**Solution**: Implemented Router Advertisement Daemon (radvd) to enable automatic IPv6 configuration.

#### Configuration
- Service: `radvd.service`
- Config: `/etc/radvd.conf`
- Interface: `usb0`

#### Features
- Sends Router Advertisements every 3-10 seconds
- Enables IPv6 link-local addresses (fe80::/64)
- Compatible with macOS Internet Connection Sharing
- Uses SLAAC (Stateless Address Autoconfiguration)

#### Host IPv6 Address
After connection, the host will have an IPv6 address like:
```
fe80::1076:5096:132b:b89%en36
```

#### Device IPv6 Address
The device's IPv6 address is derived from its MAC:
```
fe80::ecb5:adff:fe79:79c5
```

### 3. mDNS Service Broadcasting (EDG-216)

**Problem**: Devices needed to be discoverable on the network with their capabilities advertised.

**Solution**: Avahi service configuration with dynamic device UUID.

#### Implementation
- Service: `avahi-daemon`
- Config: `/etc/avahi/services/edgeos.service`
- Hostname: `edgeos-device.local`
- UUID: Dynamically generated from device serial

## Network Configuration

### USB Interface (`usb0`)

The device's USB network interface is configured via systemd-networkd:

```ini
[Network]
Address=192.168.7.1/24
DHCPServer=yes
LinkLocalAddressing=yes
IPv6LinkLocalAddressGenerationMode=eui64
```

### Services Running
- **DHCP Server**: Provides IPv4 addresses (192.168.7.x) to connected hosts
- **Router Advertisement**: Enables IPv6 link-local connectivity
- **mDNS/Avahi**: Makes device discoverable as `edgeos-device.local`

## Usage

### Connecting to the Device

1. **Via mDNS** (recommended):
   ```bash
   ssh root@edgeos-device.local
   ping6 edgeos-device.local
   ```

2. **Via IPv6 link-local**:
   ```bash
   # Find interface name (e.g., en36 on macOS)
   ifconfig | grep -B 2 "status: active"

   # Ping device
   ping6 fe80::ecb5:adff:fe79:79c5%en36
   ```

3. **Via IPv4** (when DHCP is working):
   ```bash
   ssh root@192.168.7.1
   ```

### Verifying IPv6 Connectivity

After connecting the device:

```bash
# Check if host has IPv6 address
ifconfig en36 | grep inet6

# If no IPv6, restart the network service (macOS)
networksetup -setnetworkserviceenabled "EdgeOS Device" off
sleep 2
networksetup -setnetworkserviceenabled "EdgeOS Device" on

# Test connectivity
ping6 -c 2 fe80::ecb5:adff:fe79:79c5%en36
```

### Troubleshooting

#### No IPv6 Address on Host

If the host doesn't get an IPv6 address automatically:

1. Check radvd is running on device:
   ```bash
   ssh root@edgeos-device.local systemctl status radvd
   ```

2. Restart network interface on host (see above)

3. Wait 10 seconds for Router Advertisement

#### DHCP Conflict with Internet Connection Sharing

**Issue**: When macOS Internet Connection Sharing is enabled, both the Mac and EdgeOS device try to run DHCP servers, causing conflicts.

**Workaround**: Disable ICS when connecting to EdgeOS devices, or rely on IPv6 connectivity only.

**Tracking**: EDG-295

#### Finding the Device's IPv6 Address

The device's IPv6 link-local address is predictable based on its MAC address:
- If device MAC is `ee:b5:ad:79:79:c5`
- IPv6 will be `fe80::ecb5:adff:fe79:79c5`

The MAC address follows EUI-64 format with bit 7 flipped.

## Build Configuration

### Required Yocto Layers

The following layers must be included in `bblayers.conf`:
```
meta-openembedded/meta-oe
meta-openembedded/meta-python
meta-openembedded/meta-networking
```

### Build Flags

Enable USB gadget support in `local.conf`:
```
EDGEOS_USB_GADGET = "1"
```

This enables:
- USB NCM gadget driver
- systemd-networkd configuration
- radvd for IPv6
- DHCP server

## Technical Details

### MAC Address Generation Algorithm

```bash
generate_mac() {
    local input="$1"
    local hash=$(echo -n "$input" | sha256sum | awk '{print $1}')
    local mac_base=${hash:0:12}
    # Set locally administered bit (bit 1 of first octet)
    local first_byte=${mac_base:0:2}
    local second_char=$(printf '%x' $((0x$first_byte & 0xfe | 0x02)))
    printf "%02x:%02x:%02x:%02x:%02x:%02x\n" \
       0x$second_char \
       0x${mac_base:2:2} \
       0x${mac_base:4:2} \
       0x${mac_base:6:2} \
       0x${mac_base:8:2} \
       0x${mac_base:10:2}
}
```

### Router Advertisement Configuration

Key radvd settings for USB interface:
- **MinRtrAdvInterval**: 3 seconds (aggressive for quick discovery)
- **MaxRtrAdvInterval**: 10 seconds
- **AdvDefaultLifetime**: 0 (not a default router)
- **Prefix**: fe80::/64 (link-local only)

## Related Linear Issues

- **EDG-290**: Implement dynamic MAC address generation for USB gadget
- **EDG-291**: Configure IPv6 for USB network interface
- **EDG-216**: Add mDNS/Avahi service configuration
- **EDG-295**: DHCP server conflict with macOS ICS
- **EDG-292**: Implement USB gadget connection detection
- **EDG-293**: Add USB network auto-recovery mechanism
- **EDG-294**: Create comprehensive USB troubleshooting guide

All issues are tracked under the "Host-Device USB Communication" project in Linear.