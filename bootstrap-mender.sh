#!/bin/bash
set -e

BASE_DIR=$(pwd)
SRC_DIR="${BASE_DIR}/sources"
META_EDGEOS_DIR="${BASE_DIR}/meta-edgeos"

echo "EdgeOS Build Environment Bootstrap with Mender Support"
echo "======================================================"

# Check if meta-edgeos exists
if [ ! -d "$META_EDGEOS_DIR" ]; then
    echo "Error: meta-edgeos directory not found at $META_EDGEOS_DIR"
    echo "Please run this script from the root of the edgeos repository"
    exit 1
fi

# First run the standard bootstrap
if [ ! -d "$SRC_DIR" ]; then
    echo "Running standard bootstrap first..."
    ./bootstrap.sh
fi

# Clone Mender layers
cd "$SRC_DIR"

echo "Adding Mender layers..."

# Clone meta-mender if not present
if [ ! -d "meta-mender" ]; then
    echo "  - Cloning meta-mender from https://github.com/mendersoftware/meta-mender (branch: scarthgap)"
    git clone -b scarthgap https://github.com/mendersoftware/meta-mender meta-mender
else
    echo "  - meta-mender already exists, skipping"
fi

cd "$BASE_DIR"

echo "Updating build configuration for Mender..."

# Update bblayers.conf to include Mender layers
if [ -f "build/conf/bblayers.conf" ]; then
    echo "Adding Mender layers to bblayers.conf..."
    
    # Check if Mender layers are already added
    if ! grep -q "meta-mender-core" "build/conf/bblayers.conf"; then
        cat > build/conf/bblayers.conf << 'EOF'
# POKY_BBLAYERS_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
POKY_BBLAYERS_CONF_VERSION = "2"

BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  ${TOPDIR}/../sources/poky/meta \
  ${TOPDIR}/../sources/poky/meta-poky \
  ${TOPDIR}/../sources/meta-openembedded/meta-oe \
  ${TOPDIR}/../sources/meta-openembedded/meta-python \
  ${TOPDIR}/../sources/meta-openembedded/meta-networking \
  ${TOPDIR}/../sources/meta-raspberrypi \
  ${TOPDIR}/../sources/meta-mender/meta-mender-core \
  ${TOPDIR}/../sources/meta-mender/meta-mender-raspberrypi \
  ${TOPDIR}/../meta-edgeos \
  "
EOF
        echo "Mender layers added to bblayers.conf"
    else
        echo "Mender layers already in bblayers.conf"
    fi
fi

# Add Mender configuration to local.conf if not present
if [ -f "build/conf/local.conf" ]; then
    if ! grep -q "MENDER_FEATURES_ENABLE" "build/conf/local.conf"; then
        echo ""
        echo "Adding Mender configuration to local.conf..."
        cat >> build/conf/local.conf << 'EOF'

# Mender OTA Update Configuration
# ================================
# Enable Mender client in standalone mode (no server connection)
MENDER_FEATURES_ENABLE:append = " mender-client-install"
MENDER_FEATURES_DISABLE:append = " mender-grub mender-image-uefi"

# Use standalone mode by default (no Mender server required)
MENDER_SERVER_URL = ""

# Storage device configuration - auto-detect at runtime
# Supports both SD card (mmcblk0) and NVMe (nvme0n1)
MENDER_STORAGE_DEVICE = "/dev/disk/by-path/platform-*"
MENDER_STORAGE_DEVICE_BASE = "/dev/disk/by-path/platform-*"

# Dynamic storage sizing - uses percentage of available space
# Set to 0 to use all available space (auto-expand on first boot)
MENDER_STORAGE_TOTAL_SIZE_MB = "0"
MENDER_BOOT_PART_SIZE_MB = "256"
MENDER_DATA_PART_SIZE_MB = "256"
MENDER_STORAGE_RESERVED_RAW_SPACE = "0"

# Use PARTUUID for partition identification (storage-agnostic)
MENDER_ENABLE_PARTUUID = "1"
MENDER_BOOT_PART_FSTYPE = "vfat"
MENDER_DATA_PART_FSTYPE = "ext4"

# Partition layout for A/B updates (using PARTUUID)
MENDER_BOOT_PART = "PARTUUID=${MENDER_BOOT_PARTUUID}"
MENDER_ROOTFS_PART_A = "PARTUUID=${MENDER_ROOTFS_A_PARTUUID}"
MENDER_ROOTFS_PART_B = "PARTUUID=${MENDER_ROOTFS_B_PARTUUID}"
MENDER_DATA_PART = "PARTUUID=${MENDER_DATA_PARTUUID}"

# Enable auto-expansion of root filesystem on first boot
MENDER_FEATURES_ENABLE:append = " mender-growfs-data"

# Artifact configuration
MENDER_ARTIFACT_NAME = "edgeos-${DATETIME}"

# Enable Mender systemd integration
DISTRO_FEATURES:append = " systemd"
EOF
        echo "Mender configuration added to local.conf"
    else
        echo "Mender configuration already in local.conf"
    fi
fi

echo ""
echo "Bootstrap with Mender complete!"
echo "================================"
echo ""
echo "Build environment is ready. To build EdgeOS with Mender:"
echo ""
echo "  cd $BASE_DIR"
echo "  source sources/poky/oe-init-build-env build"
echo "  bitbake edgeos-image-mender"
echo ""
echo "The built image will be at:"
echo "  tmp/deploy/images/raspberrypi5/edgeos-image-mender-raspberrypi5.sdimg"
echo ""
echo "To build the standard EdgeOS image without Mender:"
echo "  bitbake edgeos-image"