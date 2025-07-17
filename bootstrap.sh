#!/bin/bash
set -e

BASE_DIR=$(pwd)
SRC_DIR="${BASE_DIR}/sources"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

echo "Cloning layers..."
while read name url branch; do
  if [ ! -d "$name" ]; then
    echo "Cloning $name from $url (branch: $branch)"
    git clone -b "$branch" "$url" "$name"
  fi
done < "${BASE_DIR}/layers.txt"

cd "$BASE_DIR"

# We're now inside the build directory after sourcing
echo "Copying sample config..."
pwd
for f in bblayers.conf local.conf; do
  if [ ! -f "build/conf/$f" ]; then
    cp "build/conf/$f.sample" "build/conf/$f"
  fi
done

echo "Initializing build environment..."
# This creates the build/conf/ directory and sets up env
source sources/poky/oe-init-build-env build

echo "Bootstrap complete. You can now run:"
echo "  bitbake edge-image"