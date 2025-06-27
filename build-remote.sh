#!/bin/bash
set -e

REMOTE_USER="mihai"
REMOTE_HOST="192.168.68.66"
REMOTE_DIR="/home/mihai/yocto-edgeos"

echo "=== EdgeOS Remote Build Script ==="

# Sync the entire y-edgeos directory to remote
echo "Syncing EdgeOS Yocto setup to $REMOTE_USER@$REMOTE_HOST..."
rsync -avz --delete \
    --exclude='.git' \
    --exclude='build-*' \
    --exclude='poky' \
    --exclude='meta-openembedded' \
    --exclude='meta-raspberrypi' \
    ./ $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/

echo "Sync completed successfully"

# Execute the setup and build on remote server
echo "Executing remote build..."
ssh $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
    set -e
    cd /home/mihai/yocto-edgeos
    
    echo "=== Starting EdgeOS Yocto Build on Remote Server ==="
    
    # Check if we need to download layers
    if [ ! -d "poky" ]; then
        echo "Running initial setup..."
        ./setup-yocto.sh
    else
        echo "Yocto layers already exist, skipping download"
    fi
    
    # Create meta-edgeos structure if not exists
    if [ ! -d "meta-edgeos" ]; then
        echo "Creating meta-edgeos layer structure..."
        ./create-meta-edgeos.sh
    fi
    
    # Initialize build environment if not exists
    if [ ! -d "build-edgeos" ]; then
        echo "Initializing build environment..."
        ./init-build.sh
    else
        echo "Build environment already exists"
    fi
    
    # Enter build environment and start build
    echo "Starting EdgeOS image build..."
    cd build-edgeos
    source ../poky/oe-init-build-env .
    
    echo "Building edgeos-image..."
    bitbake edgeos-image
    
    echo "=== Build completed ==="
    echo "Image files available in:"
    ls -la tmp/deploy/images/raspberrypi5/
ENDSSH

echo "=== Remote build completed ==="
echo "To download the built image:"
echo "scp $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/build-edgeos/tmp/deploy/images/raspberrypi5/edgeos-image-*.rpi-sdimg ." 