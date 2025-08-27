# EdgeOS Yocto PARTUUID Implementation

This directory contains a Yocto-based implementation for Raspberry Pi 5 with proper PARTUUID support for reliable partition identification during boot.

## Overview

This implementation provides:

- **Consistent PARTUUID Support**: Proper partition UUID assignment for reliable boot
- **WIC Image Creation**: GPT-based disk images with stable partition identification
- **Boot Reliability**: Eliminates partition numbering dependencies that can cause boot failures
- **Raspberry Pi 5 Support**: Optimized for RPi5 hardware with proper boot configuration

## Architecture

### Yocto Layer Structure

```
meta-edgeos/
├── classes/
│   └── partuuid.bbclass               # UUID generation and caching logic
├── conf/
│   ├── distro/
│   │   ├── edgeos.conf                # EdgeOS distribution configuration
│   │   └── systemd.conf               # Systemd configuration
│   └── layer.conf                     # Layer configuration
├── recipes-core/
│   ├── images/
│   │   └── edgeos-image.bb            # Main image recipe with WIC support
│   ├── packagegroups/
│   │   ├── packagegroup-edgeos-base.bb     # Core system packages
│   │   ├── packagegroup-edgeos-debug.bb    # Debug/development tools
│   │   ├── packagegroup-edgeos-kernel.bb   # Kernel modules
│   │   ├── packagegroup-edgeos-uboot.bb    # U-Boot support
│   │   └── packagegroup-edgeos-wifi.bb     # WiFi support packages
│   ├── base-files/
│   │   ├── base-files_%.bbappend      # fstab PARTUUID substitution
│   │   └── files/
│   │       └── fstab                  # fstab template with UUID placeholders
│   ├── systemd/
│   │   └── systemd_%.bbappend         # Systemd customizations
│   └── usb-gadget/
│       ├── usb-gadget.bb              # USB Ethernet gadget configuration
│       └── files/                     # USB gadget scripts and services
├── recipes-bsp/
│   └── bootfiles/
│       ├── rpi-cmdline.bbappend       # cmdline.txt PARTUUID configuration
│       └── rpi-config_%.bbappend      # config.txt for UART enablement
├── recipes-support/
│   └── htop/
│       ├── htop_%.bbappend            # htop customization
│       └── files/
│           └── htoprc                 # Default htop configuration
└── wic/
    └── rpi-partuuid.wks               # WIC kickstart file for partition creation
```

## Recipe Details

### Core System Components

#### **edgeos-image.bb** - Main System Image
- **Purpose**: Defines the complete EdgeOS image with all required components
- **Features**:
  - Inherits WIC support for creating bootable SD card images
  - Includes all EdgeOS packagegroups (base, kernel, debug, wifi, etc.)
  - Configures USB gadget support when `EDGEOS_USB_GADGET=1`
  - Sets up SSH server (OpenSSH) by default
  - Defines build configuration variables for debugging and UART access

#### **packagegroup-edgeos-base.bb** - Core System Packages
- **Purpose**: Bundles essential system utilities and services
- **Includes**:
  - Core boot and extended base packages
  - System utilities: `coreutils`, `util-linux`, `iproute2`
  - Network manager: `connman`
  - Development tools: `vim`, `libstdc++`
  - Compression: `zstd`
  - Timezone data: `tzdata`
  - Conditional e2fsprogs tools when `EDGEOS_DEBUG=1`

#### **packagegroup-edgeos-debug.bb** - Debug/Development Tools
- **Purpose**: Provides debugging and performance analysis tools
- **Conditional inclusion** (only when `EDGEOS_DEBUG=1`):
  - Memory tools: `memtester`, `gperftools`
  - Storage tools: `mmc-utils`, `fio`
  - System monitoring: `htop`, `sysstat`, `procps`
  - Real-time tests: `rt-tests`
  - Network filesystem: `nfs-utils`
  - Shell and utilities: `bash`, `ldd`, `bc`

#### **packagegroup-edgeos-kernel.bb** - Kernel Modules
- **Purpose**: Includes necessary kernel modules for hardware support
- **Features**: Kernel module management and hardware drivers

#### **packagegroup-edgeos-uboot.bb** - U-Boot Support
- **Purpose**: Provides U-Boot bootloader support for advanced boot scenarios

#### **packagegroup-edgeos-wifi.bb** - WiFi Support
- **Purpose**: Bundles WiFi drivers and utilities for wireless connectivity

### USB Gadget Support

#### **usb-gadget.bb** - USB Ethernet Gadget
- **Purpose**: Enables Raspberry Pi to act as USB Ethernet device when connected to a PC
- **Components**:
  - Main script: `usb-gadget.sh` - Configures USB gadget using configfs
  - Systemd services:
    - `usb-gadget-prepare.service` - Prepares gadget configuration
    - `usb-gadget-bind@.service` - Binds gadget to UDC controller
    - `usb-gadget-unbind.service` - Cleanly unbinds gadget
  - Network configuration: `10-usb0.network` - Sets up DHCP server (192.168.7.1/24)
  - udev rules: `99-usb-gadget-udc.rules` - Auto-triggers bind on UDC detection
  - Helper script: `usb0-force-up` - Ensures usb0 interface comes up
- **Result**: Creates dual ECM+RNDIS composite gadget for compatibility with all host OSes

### Boot Configuration

#### **partuuid.bbclass** - UUID Management
- **Purpose**: Generates and caches consistent partition UUIDs across all recipes
- **Features**:
  - Creates deterministic UUIDs for boot and root partitions
  - Caches UUIDs to ensure consistency across different recipe builds
  - Provides `EDGE_BOOT_PARTUUID` and `EDGE_ROOT_PARTUUID` variables

#### **rpi-cmdline.bbappend** - Kernel Command Line
- **Purpose**: Configures boot parameters with PARTUUID support
- **Modifications**:
  - Replaces traditional `/dev/mmcblk0p2` with `PARTUUID=${EDGE_ROOT_PARTUUID}`
  - Ensures reliable boot regardless of device enumeration
  - Adds serial console configuration (115200 baud)
  - Enables filesystem check and repair on boot

#### **rpi-config_%.bbappend** - Raspberry Pi Config
- **Purpose**: Enables UART for serial console access
- **Adds**:
  - `enable_uart=1` - Enables primary UART
  - `dtoverlay=uart0` - Applies UART0 device tree overlay

#### **base-files_%.bbappend** - Filesystem Table
- **Purpose**: Configures mount points using PARTUUIDs
- **Features**:
  - Substitutes UUID placeholders in `/etc/fstab`
  - Ensures partitions mount correctly using UUIDs instead of device names

### System Configuration

#### **systemd_%.bbappend** - Systemd Customization
- **Purpose**: Configures systemd for EdgeOS requirements
- **Potential modifications**:
  - Network configuration
  - Service dependencies
  - System targets

#### **htop_%.bbappend** - System Monitor Configuration
- **Purpose**: Provides custom htop configuration
- **Features**:
  - Pre-configured layout and display options
  - Custom color scheme for EdgeOS branding
  - Optimized for embedded system monitoring

### Image Creation

#### **rpi-partuuid.wks** - WIC Kickstart File
- **Purpose**: Defines partition layout for SD card image
- **Structure**:
  - Boot partition: FAT32, contains kernel, DTBs, config files
  - Root partition: ext4, contains root filesystem
  - Both partitions assigned specific UUIDs from partuuid.bbclass

## Quick Start

### Prerequisites

- Yocto-compatible Linux system (Ubuntu 20.04+ recommended)
- At least 50GB free disk space
- 8GB+ RAM (16GB recommended for parallel builds)
- Fast internet connection for initial downloads

### Building EdgeOS

1. **Clone and Bootstrap**:
   ```bash
   git clone https://github.com/edgeengineer/meta-edgeos.git
   cd meta-edgeos
   ./bootstrap.sh
   ```
   This will download all required Yocto layers (poky, meta-raspberrypi, meta-openembedded).

2. **Configure Build** (Optional):
   ```bash
   # The default configuration is already set for Raspberry Pi 5
   # To enable USB gadget mode, add to build/conf/local.conf:
   EDGEOS_USB_GADGET = "1"
   ```

3. **Initialize Build Environment**:
   ```bash
   source sources/poky/oe-init-build-env build
   ```

4. **Build the Image**:
   ```bash
   bitbake edgeos-image
   ```
   First build takes 2-4 hours depending on your system. Subsequent builds are much faster.

5. **Find the Built Image**:
   ```bash
   ls -lh tmp/deploy/images/raspberrypi5/edgeos-image-raspberrypi5.wic*
   ```
   The `.wic` file is your complete disk image ready for flashing.

### Flashing to Storage

**To SD Card or NVMe**:
```bash
# Replace /dev/sdX with your actual device (use lsblk to find it)
sudo dd if=tmp/deploy/images/raspberrypi5/edgeos-image-raspberrypi5.wic of=/dev/sdX bs=4M status=progress conv=fsync
```

### Remote Build (Optional)

For faster builds on a dedicated server:

```bash
# Sync to build server (customize the destination)
rsync -avz --exclude='tmp' --exclude='sstate-cache' --exclude='.git' --exclude='sources' --exclude='downloads' . user@build-server:~/yocto-rpi5

# SSH to build server and build there
ssh user@build-server
cd ~/yocto-rpi5
source sources/poky/oe-init-build-env build
bitbake edgeos-image
```

## Configuration

### Build Configuration

The default machine is set to `qemux86-64` in `conf/local.conf.sample`. Edit `build-edgeos/conf/local.conf` to customize:

```bash
# Machine selection (Pi 4, Pi 5, etc.)
MACHINE = "raspberrypi5"

# Development mode (adds debugging tools)
EXTRA_IMAGE_FEATURES += "debug-tweaks"

# Parallel build settings (adjust for your system)
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"
```

### EdgeOS Configuration

Key configuration files in `meta-edgeos/recipes-support/edgeos-services/files/`:

- `edgeos-usbgadget-init.sh`: USB gadget setup script
- `edgeos-mdns-setup.service`: mDNS configuration
- `generate-uuid.sh`: Device UUID generation
- `10-edgeos-header`: Custom MOTD header

## Development

### Adding New Services

1. Add service file to `meta-edgeos/recipes-support/edgeos-services/files/`
2. Update `edgeos-services.bb` SRC_URI and SYSTEMD_SERVICE
3. Add installation commands to `do_install()`

### Modifying User Setup

Edit `meta-edgeos/recipes-core/edgeos-base/edgeos-base.bb` to change:
- User groups and permissions
- System directories
- Hostname configuration

### Debugging Build Issues

```bash
# Clean specific recipe
bitbake -c clean edgeos-services

# Rebuild with verbose output
bitbake -v edgeos-services

# Check recipe dependencies
bitbake-layers show-recipes edgeos-services
```

## Expected Results

After successful build and boot:

1. **System Boot**: Pi boots with EdgeOS branding and custom MOTD
2. **USB Gadget**: When connected to PC via USB-C, creates network interface
3. **Network Discovery**: Device accessible via `edgeos-device.local`
4. **Edge Agent**: Automatically downloads and runs on first boot
5. **Services**: All EdgeOS services start automatically
6. **User Access**: Login with `edge:edge` credentials

## Troubleshooting

### Common Build Issues

1. **Clean Rebuild After Major Changes**:
   ```bash
   bitbake -c cleansstate edgeos-image
   rm -rf tmp/
   bitbake edgeos-image
   ```

2. **USB Gadget Not Working**:
   ```bash
   # Ensure in local.conf:
   EDGEOS_USB_GADGET = "1"
   
   # Check on device:
   journalctl -u usb-gadget-prepare.service
   ```

3. **Disk Space**: Yocto builds require 50GB+ free space
4. **Layer Dependencies**: All layers must be in `conf/bblayers.conf`

### Runtime Issues

1. **USB Gadget Not Working**: Check `dmesg` for dwc2 module loading
2. **Services Not Starting**: Check `systemctl status` for specific services
3. **Network Issues**: Verify avahi-daemon is running
4. **Edge Agent Issues**: Check `/var/log/journal` for download errors

## File Locations

### On Target Device

- EdgeOS scripts: `/usr/local/sbin/`
- Edge agent: `/opt/edgeos/bin/edge-agent`
- Configuration: `/etc/edgeos/`
- Logs: `/var/log/journal/`
- Services: `/lib/systemd/system/edgeos-*.service`

### Build Artifacts

- Images: `build-edgeos/tmp/deploy/images/raspberrypi5/`
- Packages: `build-edgeos/tmp/deploy/rpm/`
- Logs: `build-edgeos/tmp/log/`

## Comparison with Original pi-gen Setup

| Feature | pi-gen | Yocto |
|---------|---------|-------|
| Build System | Bash scripts | BitBake recipes |
| Customization | Manual file copying | Recipe-based |
| Reproducibility | Limited | Full |
| Package Management | Manual | Integrated |
| Cross-compilation | Docker-based | Native |
| Maintenance | Script-heavy | Recipe-driven |

## Next Steps

1. **Test the built image** on actual Raspberry Pi hardware
2. **Validate USB gadget functionality** with host PC
3. **Verify edge-agent download and execution**
4. **Test mDNS discovery** from network clients
5. **Add production-specific configurations** (disable debug features)

## Support

For issues or questions:
- Check build logs in `build-edgeos/tmp/log/`
- Review service status with `systemctl status`
- Examine journal logs with `journalctl -u service-name` 