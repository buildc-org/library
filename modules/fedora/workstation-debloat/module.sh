dnf5 remove -y --noautoremove \
    qemu-user-static-alpha qemu-user-static-arm qemu-user-static-hexagon \
    qemu-user-static-hppa qemu-user-static-loongarch64 qemu-user-static-m68k \
    qemu-user-static-microblaze qemu-user-static-mips qemu-user-static-or1k \
    qemu-user-static-ppc qemu-user-static-riscv qemu-user-static-s390x \
    qemu-user-static-sh4 qemu-user-static-sparc qemu-user-static-x86 \
    qemu-user-static-xtensa

dnf5 remove -y --noautoremove kdump-utils kexec-tools makedumpfile

dnf5 remove -y --noautoremove sssd-ad sssd-common-pac sssd-ipa sssd-krb5 sssd-ldap

dnf5 remove -y --noautoremove NetworkManager-cloud-setup
