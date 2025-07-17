inherit partuuid

CMDLINE_ROOT_PARTITION:rpi = "PARTUUID=${EDGE_ROOT_PARTUUID}"
CMDLINE_ROOTFS:rpi = "console=serial0,115200 console=tty1 root=${CMDLINE_ROOT_PARTITION} rootfstype=ext4 fsck.repair=yes rootwait"