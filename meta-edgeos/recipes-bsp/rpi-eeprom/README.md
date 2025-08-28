# Raspberry Pi 5 EEPROM Configuration

## Overview

This recipe provides automatic EEPROM configuration for Raspberry Pi 5 devices to ensure proper USB gadget operation. It specifically addresses power delivery issues by setting `PSU_MAX_CURRENT=3000` in the EEPROM configuration.

## Problem Statement

Raspberry Pi 5 requires specific EEPROM configuration for USB gadget operation. Without proper power configuration, the device may experience:
- Power delivery negotiation failures
- Device timeout and disconnection issues
- Unreliable USB gadget functionality

## Solution

The `rpi-eeprom-config` recipe provides:

1. **Automatic Detection**: Identifies Raspberry Pi 5 hardware
2. **Configuration Check**: Verifies current EEPROM PSU_MAX_CURRENT setting
3. **Safe Update**: Stages EEPROM update and automatically reboots if needed
4. **Idempotent Operation**: Only runs once, uses flag file to prevent re-execution
5. **First Boot Operation**: Runs at first boot before any provisioning occurs

## Components

### Files

- `rpi5-eeprom-update.sh`: Main script that performs the EEPROM configuration
- `rpi5-eeprom-config.service`: Systemd service that runs once at first boot

### Operation Flow

1. System boots for the first time and systemd starts `rpi5-eeprom-config.service`
2. Service checks if already configured (flag file exists)
3. If not configured, detects hardware model
4. On RPi5, checks current EEPROM PSU_MAX_CURRENT value
5. If update needed, stages new EEPROM with PSU_MAX_CURRENT=3000
6. Creates flag file to prevent future runs
7. If update staged, automatically reboots to apply changes
8. After reboot, EEPROM is updated and service won't run again

## Integration

This recipe is included via `packagegroup-edgeos-eeprom` in the main EdgeOS image.

## Logs

All operations are logged to:
- `/var/log/rpi5-eeprom-update.log` - Detailed script log
- System journal - Via `logger` command

## Manual Verification

To verify the EEPROM configuration manually:

```bash
# Check current EEPROM configuration
sudo rpi-eeprom-config

# Look for PSU_MAX_CURRENT setting
sudo rpi-eeprom-config | grep PSU_MAX_CURRENT
```

## Dependencies

- `rpi-eeprom`: Provides the EEPROM utilities
- `bash`: Required for the update script
- `coreutils`: Basic system utilities

## Compatibility

This recipe is only compatible with Raspberry Pi 5 (`COMPATIBLE_MACHINE = "^raspberrypi5$"`)