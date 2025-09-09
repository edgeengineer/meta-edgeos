# Class to integrate Mender with EdgeOS PARTUUID system
#
# Extends the existing partuuid class to generate consistent UUIDs
# for Mender's A/B partition scheme

inherit partuuid

# Generate additional PARTUUIDs for Mender partitions
python() {
    import uuid
    
    # Use the existing EdgeOS PARTUUID generation logic
    # and extend it for Mender partitions
    
    # Get base namespace from existing partuuid class
    namespace = d.getVar('EDGE_PARTUUID_NAMESPACE') or 'edgeos'
    machine = d.getVar('MACHINE')
    
    # Generate consistent UUIDs for Mender partitions
    # RootFS A uses the existing EDGE_ROOT_PARTUUID
    d.setVar('MENDER_ROOTFS_A_PARTUUID', d.getVar('EDGE_ROOT_PARTUUID'))
    d.setVar('EDGE_ROOTFS_A_PARTUUID', d.getVar('EDGE_ROOT_PARTUUID'))
    
    # Generate UUID for RootFS B
    rootfs_b_seed = f"{namespace}-{machine}-rootfs-b"
    rootfs_b_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, rootfs_b_seed))
    d.setVar('MENDER_ROOTFS_B_PARTUUID', rootfs_b_uuid)
    d.setVar('EDGE_ROOTFS_B_PARTUUID', rootfs_b_uuid)
    
    # Generate UUID for Data partition
    data_seed = f"{namespace}-{machine}-data"
    data_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, data_seed))
    d.setVar('MENDER_DATA_PARTUUID', data_uuid)
    d.setVar('EDGE_DATA_PARTUUID', data_uuid)
    
    # Boot partition uses existing EDGE_BOOT_PARTUUID
    d.setVar('MENDER_BOOT_PARTUUID', d.getVar('EDGE_BOOT_PARTUUID'))
    
    bb.note(f"Mender PARTUUIDs generated:")
    bb.note(f"  Boot: {d.getVar('MENDER_BOOT_PARTUUID')}")
    bb.note(f"  RootFS A: {d.getVar('MENDER_ROOTFS_A_PARTUUID')}")
    bb.note(f"  RootFS B: {d.getVar('MENDER_ROOTFS_B_PARTUUID')}")
    bb.note(f"  Data: {d.getVar('MENDER_DATA_PARTUUID')}")
}

# Export variables for use in recipes and WKS files
MENDER_BOOT_PARTUUID[vardeps] += "EDGE_BOOT_PARTUUID"
MENDER_ROOTFS_A_PARTUUID[vardeps] += "EDGE_ROOT_PARTUUID"