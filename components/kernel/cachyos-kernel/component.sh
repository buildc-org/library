source /ctx/lib/kernel-helpers.sh

mkdir -p /usr/lib/kernel-build
if [ "$KERNEL" = "stock" ]; then
    echo "KERNEL=stock: keeping the Fedora base kernel, skipping CachyOS packages."
    echo "kernel-core" > /usr/lib/kernel-build/kernel-package
else
    dnf5 -y --setopt=tsflags=noscripts install --enablerepo="$COPR_BIESZCZADERS_KERNEL_CACHYOS" \
        kernel-cachyos \
        kernel-cachyos-core \
        kernel-cachyos-modules
    dnf5 -y install --enablerepo="$COPR_BIESZCZADERS_KERNEL_CACHYOS" kernel-cachyos-devel-matched

    echo "kernel-cachyos-core" > /usr/lib/kernel-build/kernel-package
    echo "kernel-cachyos-devel-matched" > /usr/lib/kernel-build/kernel-devel-package
    echo "$COPR_BIESZCZADERS_KERNEL_CACHYOS" > /usr/lib/kernel-build/kernel-devel-repo

    # cachyos-settings ships the oomd per-slice defaults that systemd-oomd-defaults also ships. The CachyOS settings replace the Fedora package.
    if rpm -q systemd-oomd-defaults > /dev/null; then
        dnf5 -y remove --noautoremove systemd-oomd-defaults
    fi

    dnf5 -y install --allowerasing --enablerepo="$COPR_BIESZCZADERS_KERNEL_CACHYOS_ADDONS" \
        ananicy-cpp \
        cachyos-ananicy-rules \
        cachyos-settings \
        scx-scheds \
        scx-tools \
        bore-sysctl

    KVER="$(kver)"

    depmod "$KVER"

    dnf5 -y install sbsigntools openssl

    source /ctx/lib/sign-helpers.sh
    if mok_signing_available; then
        SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
        sign_modules_under "/usr/lib/modules/${KVER}" "$SIGN_FILE"
        sign_vmlinuz "/usr/lib/modules/${KVER}/vmlinuz"
    else
        echo "No MOK key supplied, kernel and modules are unsigned."
    fi

    dnf5 -y remove --noautoremove kernel-cachyos-devel-matched sbsigntools

    # bootc wants exactly one kernel, so the Fedora kernel packages are removed after the CachyOS install.
    dnf5 -y remove --noautoremove kernel kernel-core kernel-modules kernel-modules-core
fi
