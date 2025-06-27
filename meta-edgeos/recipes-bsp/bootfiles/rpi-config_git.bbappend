FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add our custom config.txt file to the source files
SRC_URI += "file://config.txt"

do_deploy:append() {
    # Install our custom config.txt 
    install -m 0644 ${WORKDIR}/config.txt ${DEPLOYDIR}/${BOOTFILES_DIR_NAME}/config.txt
} 