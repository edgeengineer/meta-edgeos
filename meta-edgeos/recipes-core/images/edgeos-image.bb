DESCRIPTION = "Edge Image with WIC support"
LICENSE = "MIT"

inherit core-image image_types_wic partuuid

IMAGE_FSTYPES += "wic"
WKS_FILE = "rpi-partuuid.wks"
WKS_FILES_PATH = "${THISDIR}/../../wic"
WKS_FILE_DEPENDS += "gptfdisk"

IMAGE_FEATURES += "ssh-server-openssh"
IMAGE_INSTALL += " \
    packagegroup-edgeos-base \
    packagegroup-edgeos-kernel \
    packagegroup-edgeos-uboot \
    packagegroup-edgeos-wifi \
    packagegroup-edgeos-debug \
    "

EXTRA_IMAGEDEPENDS += "rpi-cmdline"
do_image_wic[depends] += "rpi-cmdline:do_deploy wic-tools:do_populate_sysroot e2fsprogs-native:do_populate_sysroot"

# ensure the UUIDs task ran before building the .wic
do_image_wic[depends] += "${PN}:do_generate_partuuids"

# A space-separated list of variable names that BitBake prints in the
# “Build Configuration” banner at the start of a build.
BUILDCFG_VARS += "EDGEOS_DEBUG EDGEOS_DEBUG_UART"
