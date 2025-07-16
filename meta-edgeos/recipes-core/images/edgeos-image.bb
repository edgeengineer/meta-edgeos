DESCRIPTION = "Edge Image with WIC support"
LICENSE = "MIT"

inherit core-image image_types_wic partuuid

# Add our UUID variables to WICVARS so they're available to WKS file
WICVARS:append = " EDGE_BOOT_PARTUUID EDGE_ROOT_PARTUUID"

IMAGE_FSTYPES += "wic"
WKS_FILE = "rpi-partuuid.wks"
WKS_FILES_PATH = "${THISDIR}/../../wic"
WKS_FILE_DEPENDS += "gptfdisk"

IMAGE_FEATURES += "ssh-server-openssh"
IMAGE_INSTALL += "packagegroup-core-boot vim"

EXTRA_IMAGEDEPENDS += "rpi-cmdline"
do_image_wic[depends] += "rpi-cmdline:do_deploy wic-tools:do_populate_sysroot e2fsprogs-native:do_populate_sysroot"