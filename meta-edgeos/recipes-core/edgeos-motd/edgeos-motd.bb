SUMMARY = "EdgeOS custom MOTD and welcome message"
DESCRIPTION = "Provides custom message of the day (MOTD) with EdgeOS branding and system information"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://10-edgeos-header \
           file://20-system-info \
           file://30-services \
           file://motd.conf"

S = "${WORKDIR}"

inherit allarch

# Ensure we have proper directory permissions
do_install() {
    # Create update-motd.d directory for dynamic MOTD
    install -d ${D}${sysconfdir}/update-motd.d
    
    # Install all MOTD scripts
    install -m 0755 ${WORKDIR}/10-edgeos-header ${D}${sysconfdir}/update-motd.d/
    install -m 0755 ${WORKDIR}/20-system-info ${D}${sysconfdir}/update-motd.d/
    install -m 0755 ${WORKDIR}/30-services ${D}${sysconfdir}/update-motd.d/
    
    # Create profile.d directory if it doesn't exist
    install -d ${D}${sysconfdir}/profile.d
    
    # Create a script to run update-motd on login
    cat > ${D}${sysconfdir}/profile.d/motd.sh << 'EOF'
#!/bin/sh
# Display MOTD on login
if [ -d /etc/update-motd.d ] && [ -z "$MOTD_SHOWN" ]; then
    export MOTD_SHOWN=1
    run-parts /etc/update-motd.d 2>/dev/null
fi
EOF
    chmod 0755 ${D}${sysconfdir}/profile.d/motd.sh
    
    # Create empty /etc/motd to prevent default motd
    touch ${D}${sysconfdir}/motd
}

# Package contents
FILES:${PN} = "${sysconfdir}/update-motd.d/* \
               ${sysconfdir}/profile.d/motd.sh \
               ${sysconfdir}/motd"

# Runtime dependencies
# bash for the scripts, debianutils or busybox for run-parts
RDEPENDS:${PN} = "bash debianutils-run-parts"

# Ensure this runs after base-files
RCONFLICTS:${PN} = "base-files-motd"
RREPLACES:${PN} = "base-files-motd"