
do_deploy:append() {
    echo "enable_uart=1" >> "${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt"
    echo "dtoverlay=uart0" >> "${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt"
    
    # Enable dwc2 for USB gadget support (conditional based on ENABLE_DWC2_PERIPHERAL)
    if [ "${ENABLE_DWC2_PERIPHERAL}" = "1" ]; then
        echo "dtoverlay=dwc2" >> "${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt"
    fi
}

