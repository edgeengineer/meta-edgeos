do_deploy:append() {
    # Update cmdline.txt to use filesystem label for NVMe/SD compatibility
    # This allows the same image to boot from SD card, NVMe, or USB
    if [ -f ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/cmdline.txt ]; then
        sed -i 's|root=/dev/mmcblk0p2|root=LABEL=edgeos-root|g' ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/cmdline.txt
        bbwarn "Updated cmdline.txt to use root=LABEL=edgeos-root for universal boot support"
    else
        bbwarn "cmdline.txt not found at ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/cmdline.txt"
    fi
} 