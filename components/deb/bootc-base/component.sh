NEEDS_OSTREE=2025.3
HAS_OSTREE="$(dpkg-query -W -f '${Version}' libostree-1-1)"
if ! dpkg --compare-versions "$HAS_OSTREE" ge "$NEEDS_OSTREE"; then
    echo "this base carries libostree ${HAS_OSTREE}, and bootc" \
        "${ASSET_BOOTC_VERSION} needs >= ${NEEDS_OSTREE}" >&2
    exit 1
fi

vendor="$(. /etc/os-release && echo "$ID")"
tools=/tmp/bootc-tools.tar.zst
from_source=yes
if [ "${OPT_PREBUILT_TOOLS:-0}" = 1 ]; then
    pin="ASSET_BOOTC_TOOLS_${vendor^^}"
    url="${pin}_URL"
    sha="${pin}_SHA256"
    if curl --retry 3 -fsSLo "$tools" "${!url}" \
        && echo "${!sha}  ${tools}" | sha256sum --status -c -; then
        tar --use-compress-program=zstd -xf "$tools" -C /
        from_source=no
    else
        echo "bootc-base: prebuilt-tools is set and no tarball matching" \
            "${!sha} is at ${!url}; compiling from the pins instead" >&2
    fi
    rm -f "$tools"
fi
[ "$from_source" = no ] || bash "${COMPONENT_DIR}/build-tools.sh"
ldconfig
bootc --version
bootupctl --version

shim_dir="/usr/lib/efi/shim/$(dpkg-query -W -f '${Version}' shim-signed)/EFI"
grub_dir="/usr/lib/efi/grub2/$(dpkg-query -W -f '${Version}' grub-efi-amd64-signed)/EFI"

install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/${vendor}/shimx64.efi"
install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/BOOT/BOOTX64.EFI"
if [ -f /usr/lib/shim/fbx64.efi.signed ]; then
    install -D -m 0644 /usr/lib/shim/fbx64.efi.signed "${shim_dir}/BOOT/fbx64.efi"
fi
if [ -f /usr/lib/shim/mmx64.efi.signed ]; then
    install -D -m 0644 /usr/lib/shim/mmx64.efi.signed "${shim_dir}/${vendor}/mmx64.efi"
fi
install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
    "${grub_dir}/${vendor}/grubx64.efi"

install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
    "${shim_dir}/BOOT/grubx64.efi"
install -D -m 0644 /usr/lib/shim/BOOTX64.CSV "${shim_dir}/${vendor}/BOOTX64.CSV"

install -D -m 0644 /usr/lib/bootupd/grub2-static/grub-static-efi.cfg \
    "${grub_dir}/${vendor}/grub.cfg"

bootupctl backend generate-update-metadata /
