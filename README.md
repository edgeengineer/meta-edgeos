# EdgeOS Yocto Implementation

This directory contains a complete Yocto-based implementation of EdgeOS for Raspberry Pi, providing the same functionality as the original pi-gen based system but using proper Yocto recipes and build system.

## Overview

EdgeOS is a custom Linux distribution designed for edge computing devices. This Yocto implementation includes:

- **USB Gadget Networking**: Automatic USB composite device creation with RNDIS/ECM networking
- **Edge Agent**: Automatic download and management of the EdgeOS agent
- **mDNS Discovery**: Device discoverable via `edgeos-device.local`
- **SystemD Services**: Complete service management for all EdgeOS components
- **User Management**: Pre-configured `edge` user with appropriate permissions

## Architecture

### Yocto Layers Structure

```
meta-edgeos/
├── conf/
│   └── layer.conf                    # Layer configuration
├── recipes-core/
│   ├── images/
│   │   └── edgeos-image.bb          # Main image recipe
│   ├── edgeos-base/
│   │   └── edgeos-base.bb           # User and system setup
│   └── base-files/
│       ├── base-files_%.bbappend    # Custom fstab configuration
│       └── base-files/
│           └── fstab                # Custom fstab file
├── recipes-support/
│   └── edgeos-services/
│       ├── edgeos-services.bb       # SystemD services and scripts
│       └── files/                   # All EdgeOS configuration files
├── recipes-connectivity/
│   └── edge-agent/
│       ├── edge-agent.bb            # Edge agent download and setup
│       └── files/                   # Edge agent service files
└── recipes-bsp/
    └── bootfiles/
        ├── rpi-config_git.bbappend  # Raspberry Pi USB gadget config
        ├── rpi-cmdline.bbappend     # Boot command line modifications
        └── files/
            └── config.txt           # Raspberry Pi configuration
```

### Key Components

1. **edgeos-services**: Installs all SystemD services, scripts, and configuration files
2. **edge-agent**: Downloads and installs the EdgeOS agent binary
3. **edgeos-base**: Creates the `edge` user and sets up basic system configuration
4. **edgeos-image**: Main image recipe that combines all components

## Quick Start

### Prerequisites

- Yocto-compatible Linux system (Ubuntu 20.04+ recommended)
- At least 50GB free disk space
- 8GB+ RAM recommended
- Fast internet connection for initial downloads

### Local Build

1. **Initial Setup**:
   ```bash
   ./setup-yocto.sh           # Download Yocto core and required layers
   ./create-meta-edgeos.sh    # Create meta-edgeos layer structure
   ./init-build.sh            # Initialize build environment
   ```

2. **Build EdgeOS Image**:
   ```bash
   cd build-edgeos
   bitbake edgeos-image
   ```

3. **Flash to SD Card**:
   ```bash
   sudo dd if=tmp/deploy/images/raspberrypi5/edgeos-image-raspberrypi5.rpi-sdimg of=/dev/sdX bs=4M status=progress
   ```

### Remote Build (Recommended)

For faster builds on a dedicated server:

```bash
./build-remote.sh
```

This script will:
- Sync the entire setup to `mihai@192.168.68.66`
- Execute the build remotely
- Provide instructions for downloading the built image

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

1. **Layer Dependencies**: Ensure all required layers are in `conf/bblayers.conf`
2. **Disk Space**: Yocto builds require significant disk space (50GB+)
3. **Network Issues**: Check internet connection for downloads
4. **Python Errors**: Ensure Python 3.8+ is available

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