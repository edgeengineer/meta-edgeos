# Mender OTA Update Support

EdgeOS includes support for Mender OTA (Over-The-Air) updates in standalone mode, allowing robust A/B partition updates without requiring a Mender server.

## Features

- **A/B Partition Updates**: Dual root filesystem partitions for safe updates with automatic rollback
- **Standalone Mode**: No server required - updates via USB, SD card, or local network
- **Atomic Updates**: Updates are atomic - either fully succeed or rollback
- **Power-loss Safe**: Resilient to power failures during updates
- **Automatic Rollback**: Failed boots automatically revert to previous version

## Partition Layout

The Mender-enabled EdgeOS image uses a flexible partition scheme with PARTUUID support:

| Partition | PARTUUID | Initial Size | Purpose |
|-----------|----------|--------------|---------|
| Boot | Fixed UUID | 256MB | Bootloader, kernel, device tree |
| RootFS A | Fixed UUID | ~3.5GB | Primary root filesystem |
| RootFS B | Fixed UUID | ~3.5GB | Secondary root filesystem |
| Data | Fixed UUID | 256MB | Persistent data (auto-expands) |

### Storage Device Support

EdgeOS with Mender supports multiple storage types:
- **SD Cards** (`/dev/mmcblk0`)
- **NVMe SSDs** (`/dev/nvme0n1`)
- **USB drives** (`/dev/sd*`)

The system uses PARTUUID for partition identification, making it storage-agnostic.

### Automatic Expansion

On first boot, the data partition automatically expands to use all available space on storage devices larger than 8GB. This allows the same image to work optimally on:
- 8GB SD cards (minimum)
- 32GB SD cards
- 256GB+ NVMe SSDs

## Building Mender-Enabled Image

### 1. Bootstrap with Mender Support

Use the dedicated Mender bootstrap script to add the necessary layers:

```bash
./bootstrap-mender.sh
```

This script:
- Runs the standard bootstrap first
- Downloads meta-mender layers
- Configures bblayers.conf with Mender layers
- Adds Mender configuration to local.conf

### 2. Build the Mender Image

```bash
source sources/poky/oe-init-build-env build
bitbake edgeos-image-mender
```

### 3. Flash Initial Image

Flash the generated `.sdimg` file to your SD card:

```bash
sudo dd if=tmp/deploy/images/raspberrypi5/edgeos-image-mender-raspberrypi5.sdimg \
        of=/dev/sdX bs=4M status=progress conv=fsync
```

## Creating Update Artifacts

### Generate Mender Artifact from Built Image

After building, create a `.mender` artifact:

```bash
cd tmp/deploy/images/raspberrypi5/
mender-artifact write rootfs-image \
  -n edgeos-update-v1.0 \
  -t raspberrypi5 \
  -o edgeos-update-v1.0.mender \
  -f edgeos-image-mender-raspberrypi5.ext4
```

### Create Artifact with Custom Files

```bash
mender-artifact write module-image \
  -T single-file \
  -n my-update-1.0 \
  -t raspberrypi5 \
  -o my-update-1.0.mender \
  -f /path/to/files
```

## Performing Updates

### Standalone Update via USB

1. Copy the `.mender` file to a USB drive:
```bash
cp edgeos-update-v1.0.mender /media/usb/
```

2. On the device, install the update:
```bash
mender install /media/usb/edgeos-update-v1.0.mender
```

3. Reboot to apply:
```bash
reboot
```

4. After successful boot, commit the update:
```bash
mender commit
```

### Update via Network

1. Transfer the artifact to the device:
```bash
scp edgeos-update-v1.0.mender root@edgeos-device:/tmp/
```

2. Install the update:
```bash
ssh root@edgeos-device
mender install /tmp/edgeos-update-v1.0.mender
reboot
```

3. Commit after successful boot:
```bash
mender commit
```

## Rollback

If the new update fails to boot properly, Mender automatically rolls back to the previous partition. You can also manually trigger rollback:

```bash
mender rollback
reboot
```

## Status and Debugging

### Check Current Status
```bash
mender show-artifact       # Show current running version
mender show-provides      # Show device information
mender -show-deployment   # Show deployment status
```

### View Mender Journal
```bash
journalctl -u mender-client -f
```

### Check Partition Status
```bash
fw_printenv mender_boot_part        # Current boot partition
fw_printenv mender_boot_part_hex    # Boot partition in hex
fw_printenv upgrade_available       # Update pending flag
```

## Configuration

### Mender Configuration File

Edit `/etc/mender/mender.conf` for custom settings:

```json
{
  "RootfsPartA": "/dev/mmcblk0p2",
  "RootfsPartB": "/dev/mmcblk0p3",
  "BootEnvTimeout": 10,
  "UpdatePollIntervalSeconds": 1800,
  "InventoryPollIntervalSeconds": 28800,
  "RetryPollIntervalSeconds": 300
}
```

### State Scripts

Add custom pre/post update scripts in `/etc/mender/scripts/`:

- `Download_Enter_*` - Before download
- `Download_Leave_*` - After download
- `ArtifactInstall_Enter_*` - Before install
- `ArtifactInstall_Leave_*` - After install
- `ArtifactReboot_Enter_*` - Before reboot
- `ArtifactCommit_Enter_*` - Before commit

## Troubleshooting

### Update Fails to Install
- Check available space: `df -h /`
- Verify artifact compatibility: `mender-artifact read artifact.mender`
- Check logs: `journalctl -u mender-client`

### Device Stuck in Reboot Loop
- Power off and remove SD card
- Mount on another system and check `/data/mender/`
- Delete `mender.lock` if present
- Check bootloader environment in `/boot/`

### Manual Partition Switch
```bash
# Switch to other partition
fw_setenv mender_boot_part 3  # Switch to partition 3 (B)
fw_setenv mender_boot_part 2  # Switch to partition 2 (A)
reboot
```

## Best Practices

1. **Always Test Updates**: Test on development hardware before production
2. **Version Your Artifacts**: Use semantic versioning in artifact names
3. **Backup Data Partition**: Important data should be backed up before major updates
4. **Monitor First Boot**: Watch serial console or SSH during first boot after update
5. **Implement Health Checks**: Add state scripts to verify system health post-update

## Limitations

- Standalone mode requires manual update management
- No remote deployment without Mender server
- Bootloader updates not supported in current configuration
- Requires minimum 8GB SD card for dual partitions

## Advanced Usage

### Enable Mender Server Mode

To connect to a hosted or self-hosted Mender server, update `/etc/mender/mender.conf`:

```json
{
  "ServerURL": "https://hosted.mender.io",
  "TenantToken": "YOUR_TENANT_TOKEN"
}
```

### Delta Updates

For bandwidth-efficient updates, enable delta updates:

```bash
MENDER_FEATURES_ENABLE:append = " mender-binary-delta"
```

Then generate delta artifacts:

```bash
mender-artifact write rootfs-image-delta \
  -n update-v2 \
  -t raspberrypi5 \
  -o delta-update.mender \
  --base-artifact previous.mender \
  --rootfs-image new-rootfs.ext4
```