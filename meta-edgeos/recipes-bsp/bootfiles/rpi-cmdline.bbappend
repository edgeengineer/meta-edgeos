inherit partuuid

CMDLINE_ROOT_PARTITION:rpi = "PARTUUID=${EDGE_ROOT_PARTUUID}"

# Replace any existing root=... with PARTUUID
CMDLINE_ROOTFS:remove = "root=[^ ]+"
CMDLINE_ROOTFS:rpi = "console=serial0,115200 root=${CMDLINE_ROOT_PARTITION} rootfstype=ext4 fsck.repair=yes rootwait"

# ensure values are materialized (audit file handy)
do_deploy[depends] += "${PN}:do_generate_partuuids"
