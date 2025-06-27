SUMMARY = "EdgeOS minimal image for Raspberry Pi"
DESCRIPTION = "Minimal EdgeOS image with core functionality"

inherit core-image

# Accept restricted licenses for firmware
LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"

# Minimal packages for EdgeOS functionality
IMAGE_INSTALL = " \
    packagegroup-core-boot \
    kernel-modules \
    openssh \
    curl \
    wget \
    ca-certificates \
    tzdata \
    util-linux \
    procps \
    avahi-daemon \
    avahi-utils \
    python3 \
    bash \
    networkmanager \
    networkmanager-nmcli \
    udev \
    kmod \
    findutils \
    coreutils \
    iproute2 \
    iputils-ping \
    file \
    util-linux \
    sed \
    grep \
    gawk \
    tar \
    systemd \
    systemd-analyze \
    busybox \
    edgeos-services \
    edge-agent \
    edgeos-base \
"

# Enable systemd and networking features
DISTRO_FEATURES:append = " systemd wifi bluetooth"
VIRTUAL-RUNTIME_init_manager = "systemd"
VIRTUAL-RUNTIME_initscripts = ""

# Image features
IMAGE_FEATURES += "ssh-server-openssh"

# Extra space for EdgeOS components
IMAGE_ROOTFS_EXTRA_SPACE = "512000"

# Raspberry Pi boot partition size (in KB) - increased for kernel + overlays
BOOT_SPACE = "102400"

# Image formats - include SD card image for Raspberry Pi
IMAGE_FSTYPES = "tar.xz rpi-sdimg"

# Set filesystem label for device-agnostic booting
SDIMG_ROOTFS_LABEL = "edgeos-root"

# Development features
EXTRA_IMAGE_FEATURES += "debug-tweaks"

# Set root password for development
EXTRA_USERS_PARAMS = "usermod -P edge root;"

# Disable problematic Pi-specific features
MACHINE_FEATURES:remove = "vc4graphics" 