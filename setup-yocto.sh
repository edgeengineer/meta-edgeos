#!/bin/bash
set -e

echo "=== EdgeOS Yocto Setup ==="
echo "Setting up Yocto environment for EdgeOS..."

# Create workspace
WORKSPACE_DIR="$(pwd)"
echo "Working in: $WORKSPACE_DIR"

# Step 1.3: Download Yocto Core (Poky)
if [ ! -d "poky" ]; then
    echo "Downloading Yocto Poky (scarthgap)..."
    git clone -b scarthgap git://git.yoctoproject.org/poky
else
    echo "Poky already exists, skipping download"
fi

# Step 1.4: Download Required Meta Layers
if [ ! -d "meta-raspberrypi" ]; then
    echo "Downloading meta-raspberrypi..."
    git clone -b scarthgap https://github.com/agherzan/meta-raspberrypi.git
else
    echo "meta-raspberrypi already exists, skipping download"
fi

if [ ! -d "meta-openembedded" ]; then
    echo "Downloading meta-openembedded..."
    git clone -b scarthgap https://github.com/openembedded/meta-openembedded.git
else
    echo "meta-openembedded already exists, skipping download"
fi

echo "=== Yocto layers downloaded successfully ==="
echo "Next steps:"
echo "1. Run ./create-meta-edgeos.sh to create the EdgeOS layer"
echo "2. Run ./init-build.sh to initialize the build environment"
echo "3. Run bitbake edgeos-image to build the image" 