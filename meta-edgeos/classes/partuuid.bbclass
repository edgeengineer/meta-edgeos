# partuuid.bbclass - Generate and cache UUIDs for partition references

python __anonymous() {
    import uuid
    import os
    
    # Use build directory for caching UUIDs to ensure consistency within a build
    build_dir = d.getVar('TOPDIR')
    uuid_cache_dir = build_dir + '/uuid-cache'
    uuid_cache_file = uuid_cache_dir + '/partuuids.conf'
    
    # Ensure cache directory exists
    if not os.path.exists(uuid_cache_dir):
        os.makedirs(uuid_cache_dir)
    
    # Try to read existing cached UUIDs
    boot_uuid = None
    root_uuid = None
    
    if os.path.exists(uuid_cache_file):
        try:
            with open(uuid_cache_file, 'r') as f:
                content = f.read()
                for line in content.split('\n'):
                    if line.startswith('EDGE_BOOT_PARTUUID='):
                        boot_uuid = line.split('=', 1)[1].strip()
                    elif line.startswith('EDGE_ROOT_PARTUUID='):
                        root_uuid = line.split('=', 1)[1].strip()
        except:
            pass
    
    # Generate new UUIDs if not found in cache
    if not boot_uuid or not root_uuid:
        boot_uuid = str(uuid.uuid4())
        root_uuid = str(uuid.uuid4())
        
        # Cache the UUIDs for other recipes
        try:
            with open(uuid_cache_file, 'w') as f:
                f.write(f'EDGE_BOOT_PARTUUID={boot_uuid}\n')
                f.write(f'EDGE_ROOT_PARTUUID={root_uuid}\n')
        except Exception as e:
            bb.warn(f"Failed to cache UUIDs: {e}")
    
    # Set as BitBake variables
    d.setVar('EDGE_BOOT_PARTUUID', boot_uuid)
    d.setVar('EDGE_ROOT_PARTUUID', root_uuid)
    
    bb.note(f'Using Boot PARTUUID: {boot_uuid}')
    bb.note(f'Using Root PARTUUID: {root_uuid}')
} 