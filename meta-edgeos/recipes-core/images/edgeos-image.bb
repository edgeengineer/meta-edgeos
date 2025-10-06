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
    packagegroup-edgeos-eeprom \
    "

# enable USB peripheral (gadget) support
ENABLE_DWC2_PERIPHERAL = "${@oe.utils.ifelse(d.getVar('EDGEOS_USB_GADGET') == '1', '1', '0')}"
IMAGE_INSTALL += " ${@oe.utils.ifelse(d.getVar('EDGEOS_USB_GADGET') == '1', ' usb-gadget radvd', '')}"

# enable container runtime support
IMAGE_INSTALL += " ${@oe.utils.ifelse(d.getVar('EDGEOS_CONTAINER_RUNTIME') == '1', ' packagegroup-edgeos-container', '')}"

EXTRA_IMAGEDEPENDS += "rpi-cmdline"
do_image_wic[depends] += "rpi-cmdline:do_deploy wic-tools:do_populate_sysroot e2fsprogs-native:do_populate_sysroot"

# ensure the UUIDs task ran before building the .wic
do_image_wic[depends] += "${PN}:do_generate_partuuids"

# A space-separated list of variable names that BitBake prints in the
# “Build Configuration” banner at the start of a build.
BUILDCFG_VARS += " \
    EDGEOS_DEBUG \
    EDGEOS_DEBUG_UART \
    EDGEOS_USB_GADGET \
    EDGEOS_PERSIST_JOURNAL_LOGS \
    EDGEOS_CONTAINER_RUNTIME \
    "

# Disable WIC's automatic fstab updates
WIC_CREATE_EXTRA_ARGS = "--no-fstab-update"

IMAGE_INSTALL:append = "expand-rootfs"
IMAGE_INSTALL += "${@bb.utils.contains('EDGEOS_DISABLE_ROOT_SSH', '1', 'edgeos-user', '', d)}"

ROOTFS_POSTPROCESS_COMMAND += "edgeos_make_admin_nopass;"

edgeos_make_admin_nopass () {
    if [ "${EDGEOS_DISABLE_ROOT_SSH}" = "1" ] && [ -f ${IMAGE_ROOTFS}/etc/shadow ]; then
        sed -i 's/^admin:[^:]*:/admin::/' ${IMAGE_ROOTFS}/etc/shadow || true
    fi
}
# Provider for 'hostname' required by avahi-daemon
IMAGE_INSTALL:append = " inetutils-hostname"

# Avahi + the sub-package with the custom script/service
IMAGE_INSTALL:append = " avahi-daemon avahi-edgeos-hostname"
