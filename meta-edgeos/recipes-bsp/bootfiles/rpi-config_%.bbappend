
do_deploy:append() {
    echo "enable_uart=1" >> "${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt"
    echo "dtoverlay=uart0" >> "${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt"
}

