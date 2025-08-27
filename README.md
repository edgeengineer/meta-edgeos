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
│   └── layer.conf                     # Layer configuration
├── recipes-core/
│   ├── images/
│   │   └── edge-image.bb              # Main image recipe with WIC support
│   └── base-files/
│       ├── base-files_%.bbappend      # fstab PARTUUID substitution
│       └── files/
│           └── fstab                  # fstab template with UUID placeholders
├── recipes-bsp/
│   └── bootfiles/
│       └── rpi-cmdline.bbappend       # cmdline.txt PARTUUID configuration
└── wic/
    └── rpi-partuuid.wks               # WIC kickstart file for partition creation
```

### Key Components

1. **partuuid.bbclass**: Generates and caches consistent UUIDs across all recipes
2. **edge-image.bb**: Main image recipe with WIC configuration and PARTUUID variables
3. **base-files append**: Substitutes UUIDs in fstab for proper mount point identification
4. **rpi-cmdline append**: Configures kernel command line with root PARTUUID
5. **rpi-partuuid.wks**: WIC kickstart file that creates partitions with specified UUIDs

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