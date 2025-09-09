#!/bin/bash
set -e

BASE_DIR=$(pwd)
SRC_DIR="${BASE_DIR}/sources"
META_EDGEOS_DIR="${BASE_DIR}/meta-edgeos"

echo "EdgeOS Build Environment Bootstrap"
echo "=================================="

# Check if meta-edgeos exists
if [ ! -d "$META_EDGEOS_DIR" ]; then
    echo "Error: meta-edgeos directory not found at $META_EDGEOS_DIR"
    echo "Please run this script from the root of the edgeos repository"
    exit 1
fi

# Clone source layers
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

echo "Cloning source layers..."
while read name url branch; do
  if [ ! -d "$name" ]; then
    echo "  - Cloning $name from $url (branch: $branch)"
    git clone -b "$branch" "$url" "$name"
  else
    echo "  - $name already exists, skipping"
  fi
done < "${BASE_DIR}/layers.txt"

cd "$BASE_DIR"

echo "Initializing build environment..."
# This creates the build/conf/ directory and sets up env
source sources/poky/oe-init-build-env build

# Now we're in the build directory
echo "Setting up configuration..."

# Set up bblayers.conf - always overwrite to ensure correct layers
if [ -f "conf/bblayers.conf" ]; then
    echo "Updating bblayers.conf with EdgeOS layers..."
else
    echo "Creating bblayers.conf..."
fi

cat > conf/bblayers.conf << 'EOF'
# POKY_BBLAYERS_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
POKY_BBLAYERS_CONF_VERSION = "2"

BBPATH = "${TOPDIR}"
BBFILES ?= ""

BBLAYERS ?= " \
  ${TOPDIR}/../sources/poky/meta \
  ${TOPDIR}/../sources/poky/meta-poky \
  ${TOPDIR}/../sources/meta-openembedded/meta-oe \
  ${TOPDIR}/../sources/meta-raspberrypi \
  ${TOPDIR}/../meta-edgeos \
  "
EOF

# Set up local.conf from template
if [ -f "conf/local.conf" ]; then
    # Check if this is the default Poky local.conf (by looking for a unique EdgeOS marker)
    if ! grep -q "EdgeOS Build Configuration" "conf/local.conf" 2>/dev/null; then
        echo "Replacing default local.conf with EdgeOS template..."
        mv conf/local.conf conf/local.conf.backup.$(date +%Y%m%d_%H%M%S)
        cp "${META_EDGEOS_DIR}/conf/local.conf.template" "conf/local.conf"
        echo "local.conf created from EdgeOS template (original backed up)."
    else
        echo "EdgeOS local.conf already exists, preserving your customizations."
    fi
else
    echo "Creating local.conf from template..."
    cp "${META_EDGEOS_DIR}/conf/local.conf.template" "conf/local.conf"
    echo "local.conf created from EdgeOS template."
fi

echo ""
echo "Bootstrap complete!"
echo "=================="
echo ""
echo "Build environment is ready. To build EdgeOS:"
echo ""
echo "  cd $BASE_DIR"
echo "  source sources/poky/oe-init-build-env build"
echo "  bitbake edgeos-image"
echo ""
echo "The built image will be at:"
echo "  tmp/deploy/images/raspberrypi5/edgeos-image-raspberrypi5.rootfs.wic"