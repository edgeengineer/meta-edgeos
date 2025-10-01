SUMMARY = "Create 'admin' user (UID 1000) with home directory"
DESCRIPTION = "Adds a non-root 'admin' user and /home/admin. Password is cleared at image time via EXTRA_USERS_PARAMS when EDGEOS_DISABLE_ROOT_SSH=1."
LICENSE = "CLOSED"
PR = "r0"

inherit useradd

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "-u 1000 -d /home/admin -m -s /bin/bash admin"
FILES:${PN} += "/home/admin"

do_install() {
    install -d ${D}/home/admin
    chown -R 1000:1000 ${D}/home/admin || true
}
