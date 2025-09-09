# EdgeOS image with Mender OTA support
require edgeos-image.bb

DESCRIPTION = "EdgeOS image with Mender OTA update support"

# Ensure Mender is included
IMAGE_INSTALL:append = " mender-client mender-artifact-info"

# Enable Mender features for the image
MENDER_FEATURES_ENABLE:append = " mender-image mender-client-install"

# Set up proper image types for Mender
IMAGE_FSTYPES:remove = "wic wic.bmap"
IMAGE_FSTYPES:append = " mender ext4"

# Use Mender-compatible WKS file
WKS_FILE = "rpi-mender.wks"