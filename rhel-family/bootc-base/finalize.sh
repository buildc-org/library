# ---- the initramfs ----
mapfile -t kvers < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
if [ "${#kvers[@]}" -ne 1 ]; then
    echo "bootc wants exactly one kernel; /usr/lib/modules has: ${kvers[*]}" >&2
    exit 1
fi
kver="${kvers[0]}"
[ -f "/usr/lib/modules/${kver}/vmlinuz" ] || {
    echo "the kernel package left no /usr/lib/modules/${kver}/vmlinuz" >&2
    exit 1
}
depmod "$kver"
initramfs="/usr/lib/modules/${kver}/initramfs.img"
dracut --force --kver "$kver" "$initramfs"

listing="$(lsinitrd "$initramfs")"
for path in usr/lib/ostree/ostree-prepare-root \
    usr/lib/bootc/initramfs-setup; do
    if ! grep -q "[ /]${path}\$" <<< "$listing"; then
        echo "the initramfs carries no ${path}, so it cannot mount a deployment" >&2
        exit 1
    fi
done

# ---- what a build must not bake in ----
: > /etc/machine-id
find /run -mindepth 1 -maxdepth 1 ! -name secrets ! -name .containerenv \
    -exec rm -rf {} +
rm -f /etc/ssh/ssh_host_*
rm -f /etc/fstab

# ---- the bootloader payload ----
mkdir -p /usr/lib/ostree-boot
mv /boot/efi /usr/lib/ostree-boot/efi
bootupctl backend generate-update-metadata

# ---- the ostree-shaped root ----
# shellcheck disable=SC2114 # replacing the system directories is the point
rm -rf /home /root /srv /mnt /boot
mkdir -p /boot /sysroot /var/home /var/srv /var/mnt /var/roothome
chmod 0700 /var/roothome
ln -sT var/home /home
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT sysroot/ostree /ostree
