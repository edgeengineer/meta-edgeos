FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add container support kernel config when EDGEOS_CONTAINER_RUNTIME is enabled
SRC_URI:append = "${@' file://container.cfg' if d.getVar('EDGEOS_CONTAINER_RUNTIME') == '1' else ''}"

# Enable kernel configuration fragments
KERNEL_CONFIG_FRAGMENTS:append = "${@' ${WORKDIR}/container.cfg' if d.getVar('EDGEOS_CONTAINER_RUNTIME') == '1' else ''}"