inherit partuuid

CMDLINE_ROOT_PARTITION:rpi = "PARTUUID=${EDGE_ROOT_PARTUUID}"

# Replace any existing root=... with PARTUUID
CMDLINE_ROOTFS:remove = "root=[^ ]+"

# Base cmdline without dwc2
CMDLINE_ROOTFS:rpi = "console=serial0,115200 root=${CMDLINE_ROOT_PARTITION} rootfstype=ext4 fsck.repair=yes rootwait"

# Add dwc2 module loading only when USB gadget is enabled
CMDLINE_ROOTFS:rpi:append = "${@' modules-load=dwc2' if d.getVar('ENABLE_DWC2_PERIPHERAL') == '1' else ''}"

# ensure values are materialized (audit file handy)
do_deploy[depends] += "${PN}:do_generate_partuuids"
