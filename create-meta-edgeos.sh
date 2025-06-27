#!/bin/bash
set -e

echo "=== Creating meta-edgeos layer ==="

# Step 2.1: Create Layer Structure
echo "Creating layer directory structure..."
mkdir -p meta-edgeos/{conf,recipes-core,recipes-support,recipes-connectivity,recipes-bsp}
mkdir -p meta-edgeos/recipes-core/{images,edgeos-base}
mkdir -p meta-edgeos/recipes-support/edgeos-services
mkdir -p meta-edgeos/recipes-connectivity/edge-agent
mkdir -p meta-edgeos/recipes-bsp/bootfiles

echo "Layer structure created successfully"
echo "Next: Layer configuration, recipes, and files will be created by separate scripts" 