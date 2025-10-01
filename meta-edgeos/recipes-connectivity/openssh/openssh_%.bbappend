# meta-edgeos/recipes-connectivity/openssh/openssh_%.bbappend

do_install:append() {
    if [ "${EDGEOS_DISABLE_ROOT_SSH}" = "1" ]; then
        install -d ${D}${sysconfdir}/ssh/sshd_config.d
        cat > ${D}${sysconfdir}/ssh/sshd_config.d/10-disable-root.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication yes
PermitEmptyPasswords yes
UsePAM no
EOF
    fi
}

# The file is only installed when the flag is "1",
# but it's safe to declare it in FILES regardless.
FILES:${PN}-sshd += "${sysconfdir}/ssh/sshd_config.d/10-disable-root.conf"
