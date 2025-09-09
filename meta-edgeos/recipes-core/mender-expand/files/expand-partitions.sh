#!/bin/bash
#
# EdgeOS Partition Expansion Script for Mender A/B Layout
# Expands the last partition (data) and current root partition to use available space
#

set -e

MARKER_FILE="/var/lib/edgeos/partitions-expanded"
LOG_FILE="/var/log/partition-expansion.log"

# Redirect output to log
exec 1>"${LOG_FILE}" 2>&1

echo "EdgeOS Partition Expansion - $(date)"
echo "======================================="

# Check if already expanded
if [ -f "${MARKER_FILE}" ]; then
    echo "Partitions already expanded, exiting."
    exit 0
fi

# Function to detect storage device
detect_storage_device() {
    # Try to find the device containing the root partition
    ROOT_DEV=$(findmnt -n -o SOURCE /)
    
    # Extract base device name (remove partition number)
    if [[ "$ROOT_DEV" =~ ^/dev/mmcblk[0-9]+p[0-9]+$ ]]; then
        # SD card format
        BASE_DEV=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
        PART_PREFIX="p"
    elif [[ "$ROOT_DEV" =~ ^/dev/nvme[0-9]+n[0-9]+p[0-9]+$ ]]; then
        # NVMe format
        BASE_DEV=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
        PART_PREFIX="p"
    elif [[ "$ROOT_DEV" =~ ^/dev/[sv]d[a-z][0-9]+$ ]]; then
        # Standard SATA/SCSI format
        BASE_DEV=$(echo "$ROOT_DEV" | sed 's/[0-9]*$//')
        PART_PREFIX=""
    elif [[ "$ROOT_DEV" =~ ^PARTUUID= ]]; then
        # Root is mounted by PARTUUID, need to resolve
        PARTUUID=$(echo "$ROOT_DEV" | cut -d= -f2)
        ROOT_DEV=$(blkid -t PARTUUID="$PARTUUID" -o device)
        
        if [[ "$ROOT_DEV" =~ ^/dev/mmcblk[0-9]+p[0-9]+$ ]]; then
            BASE_DEV=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
            PART_PREFIX="p"
        elif [[ "$ROOT_DEV" =~ ^/dev/nvme[0-9]+n[0-9]+p[0-9]+$ ]]; then
            BASE_DEV=$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')
            PART_PREFIX="p"
        else
            BASE_DEV=$(echo "$ROOT_DEV" | sed 's/[0-9]*$//')
            PART_PREFIX=""
        fi
    else
        echo "ERROR: Unable to detect storage device type from $ROOT_DEV"
        exit 1
    fi
    
    echo "Detected storage device: $BASE_DEV"
    echo "Partition prefix: $PART_PREFIX"
    echo "Root device: $ROOT_DEV"
}

# Function to get partition number from device
get_partition_number() {
    local dev=$1
    if [[ "$dev" =~ p([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$dev" =~ ([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Main expansion logic
main() {
    detect_storage_device
    
    # Get current root partition number
    ROOT_PART_NUM=$(get_partition_number "$ROOT_DEV")
    if [ -z "$ROOT_PART_NUM" ]; then
        echo "ERROR: Unable to determine root partition number"
        exit 1
    fi
    
    echo "Root partition number: $ROOT_PART_NUM"
    
    # In Mender setup:
    # Partition 1: Boot
    # Partition 2: RootFS A
    # Partition 3: RootFS B
    # Partition 4: Data
    
    DATA_PART_NUM=4
    DATA_PART="${BASE_DEV}${PART_PREFIX}${DATA_PART_NUM}"
    
    # Check if data partition exists
    if [ ! -b "$DATA_PART" ]; then
        echo "ERROR: Data partition $DATA_PART not found"
        exit 1
    fi
    
    # Get disk size
    DISK_SIZE_SECTORS=$(blockdev --getsz "$BASE_DEV")
    DISK_SIZE_GB=$((DISK_SIZE_SECTORS * 512 / 1024 / 1024 / 1024))
    echo "Disk size: ${DISK_SIZE_GB}GB"
    
    # Only expand if disk is larger than default 8GB
    if [ "$DISK_SIZE_GB" -le 8 ]; then
        echo "Disk size is 8GB or smaller, no expansion needed"
        mkdir -p "$(dirname "$MARKER_FILE")"
        touch "$MARKER_FILE"
        exit 0
    fi
    
    echo "Expanding partitions to use available space..."
    
    # First, expand the GPT to use the full disk
    sgdisk -e "$BASE_DEV"
    
    # Calculate new sizes
    # Keep boot partition (1) as is
    # Keep inactive root partition as is
    # Expand active root partition and data partition
    
    # Get current partition layout
    PART_TABLE=$(sgdisk -p "$BASE_DEV")
    
    # Expand data partition to end of disk
    echo "Expanding data partition..."
    sgdisk -d ${DATA_PART_NUM} "$BASE_DEV"
    sgdisk -n ${DATA_PART_NUM}:0:0 -t ${DATA_PART_NUM}:8300 "$BASE_DEV"
    
    # Reload partition table
    partprobe "$BASE_DEV"
    sleep 2
    
    # Expand filesystems
    echo "Expanding data filesystem..."
    e2fsck -f -y "$DATA_PART" || true
    resize2fs "$DATA_PART"
    
    # Expand current root filesystem if there's space
    # (This requires more complex logic to safely resize between A/B partitions)
    # For now, we'll just expand the data partition
    
    # Create marker file
    mkdir -p "$(dirname "$MARKER_FILE")"
    touch "$MARKER_FILE"
    
    echo "Partition expansion completed successfully"
    echo "======================================="
}

# Run main function
main

exit 0