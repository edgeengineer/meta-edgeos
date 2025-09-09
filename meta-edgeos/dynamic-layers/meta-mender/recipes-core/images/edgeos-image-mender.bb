# EdgeOS image with Mender OTA support
require edgeos-image.bb

DESCRIPTION = "EdgeOS image with Mender OTA update support"

# Ensure Mender is included
IMAGE_INSTALL:append = " mender-client mender-artifact-info"

# Enable Mender features for the image
MENDER_FEATURES_ENABLE:append = " mender-image mender-client-install mender-partuuid"

# Set up proper image types for Mender
IMAGE_FSTYPES:remove = "wic wic.bmap"
IMAGE_FSTYPES:append = " mender ext4"

# Use Mender-compatible WKS file with PARTUUID support
WKS_FILE = "rpi-mender.wks"

# Enable PARTUUID for storage-agnostic booting
MENDER_ENABLE_PARTUUID = "1"

# Generate fixed PARTUUIDs for consistent booting
inherit mender-partuuid

# Enable Mender in distro for this image
DISTRO_FEATURES:append = " mender-client-install"
INHERIT += "mender-full"