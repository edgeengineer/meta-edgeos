#!/bin/bash
set -e

# EdgeOS Yocto Build Initialization Script
# This script initializes the Yocto build environment for EdgeOS
# 
# Configuration files are copied from templates:
# - conf/bblayers.conf.sample -> build-edgeos/conf/bblayers.conf (${OEROOT} variable available)
# - conf/local.conf.sample -> build-edgeos/conf/local.conf (direct copy)

echo "=== Initializing EdgeOS Yocto Build Environment ==="

WORKSPACE_DIR="$(pwd)"
BUILD_DIR="build-edgeos"

# Initialize build environment
echo "Initializing build environment..."
source poky/oe-init-build-env $BUILD_DIR

# Get the absolute path to the workspace
WORKSPACE_ABS=$(cd "$WORKSPACE_DIR" && pwd)

echo "=== Configuring build environment ==="

# Configure bblayers.conf from template
echo "Configuring layers..."
if [ -f "$WORKSPACE_ABS/conf/bblayers.conf.sample" ]; then
    cp "$WORKSPACE_ABS/conf/bblayers.conf.sample" conf/bblayers.conf
else
    echo "Error: bblayers.conf.sample not found in $WORKSPACE_ABS/conf/"
    exit 1
fi

# Configure local.conf from template
echo "Configuring local.conf..."
if [ -f "$WORKSPACE_ABS/conf/local.conf.sample" ]; then
    cp "$WORKSPACE_ABS/conf/local.conf.sample" conf/local.conf
else
    echo "Error: local.conf.sample not found in $WORKSPACE_ABS/conf/"
    exit 1
fi

echo "=== Build environment configured ==="
echo ""
echo "To build EdgeOS image:"
echo "1. cd $BUILD_DIR"
echo "2. bitbake edgeos-image"
echo ""
echo "Build will be available in tmp/deploy/images/raspberrypi5/" 