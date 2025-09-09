inherit partuuid
inherit journal-persist

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://fstab"

# EdgeOS branding configuration
EDGEOS_HOSTNAME ?= "edgeos-device"

# Get git commit hash for build tracking (deterministic within same commit)
# Falls back to "dev" if not in a git repo
def get_git_hash(d):
    import subprocess
    try:
        return subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], 
                                      cwd=d.getVar('TOPDIR')).decode('utf-8').strip()
    except:
        return "dev"

# Use git commit hash for build ID by default
# Can be overridden in local.conf with EDGEOS_BUILD_ID = "${DATETIME}" or any other value
EDGEOS_BUILD_ID ?= "${@get_git_hash(d)}"

do_install:append() {
    # Process fstab template with dynamic UUIDs from partuuid class
    install -m 0644 ${WORKDIR}/fstab ${D}${sysconfdir}/fstab

    # Replace UUID placeholders with actual values
    sed -i 's/RPI_BOOT_UUID/${EDGE_BOOT_PARTUUID}/g' ${D}${sysconfdir}/fstab
    sed -i 's/RPI_ROOT_UUID/${EDGE_ROOT_PARTUUID}/g' ${D}${sysconfdir}/fstab
    
    # Clear the default motd file - our custom MOTD will be shown dynamically
    # This prevents the static motd from conflicting with our dynamic one
    echo "" > ${D}${sysconfdir}/motd

    # Set EdgeOS hostname
    echo "${EDGEOS_HOSTNAME}" > ${D}${sysconfdir}/hostname

    # Generate EdgeOS build ID file
    echo "EdgeOS-${EDGEOS_BUILD_ID}" > ${D}${sysconfdir}/edgeos-build-id
    chmod 644 ${D}${sysconfdir}/edgeos-build-id
}

# Make UUID changes trigger rebuilds wherever they’re used
do_install[vardeps] += "EDGE_BOOT_PARTUUID EDGE_ROOT_PARTUUID"

# systemd persistent log
# If '/var/log' is a symlink into '/var/volatile/log', journald can’t persist
# the logs and packaging any /var/log/* hits the "directory symlink" QA error.
# Guard against out-of-tree layers creating a symlink directly in ${D}.
do_install:append:journal_persist-on() {
    if [ -L ${D}${localstatedir}/log ]; then
        rm -f ${D}${localstatedir}/log
        install -d -m 0755 ${D}${localstatedir}/log
    fi

}
