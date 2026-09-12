# ---- the initramfs ----
kver="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')"
if [ -z "$kver" ] || [ "$(printf '%s\n' "$kver" | wc -l)" != 1 ]; then
    echo "bootc wants exactly one kernel; /usr/lib/modules has: ${kver}" >&2
    exit 1
fi
[ -f "/usr/lib/modules/${kver}/vmlinuz" ] \
    || cp "/boot/vmlinuz-${kver}" "/usr/lib/modules/${kver}/vmlinuz"
depmod "$kver"
initramfs="/usr/lib/modules/${kver}/initramfs.img"
dracut --force --kver "$kver" "$initramfs"

listing="$(lsinitrd "$initramfs")"
for path in usr/lib/bootc/initramfs-setup \
    usr/lib/systemd/system/bootc-root-setup.service \
    usr/bin/systemd-cryptsetup; do
    if ! grep -q "[ /]${path}\$" <<< "$listing"; then
        echo "the initramfs carries no ${path}, so a machine from this image cannot boot" >&2
        exit 1
    fi
done

# ---- package state out of /var ----
mkdir -p /usr/lib/sysimage
for pair in \
    dpkg:/var/lib/dpkg \
    pam:/var/lib/pam \
    ucf:/var/lib/ucf \
    sgml-base:/var/lib/sgml-base \
    xml-core:/var/lib/xml-core \
    deb-systemd-helper-enabled:/var/lib/systemd/deb-systemd-helper-enabled \
    deb-systemd-user-helper-enabled:/var/lib/systemd/deb-systemd-user-helper-enabled; do
    from="${pair#*:}"
    to="/usr/lib/sysimage/${pair%%:*}"
    [ -L "$from" ] && continue
    if [ -d "$from" ]; then mv "$from" "$to"; else mkdir -p "$to"; fi
    mkdir -p "$(dirname "$from")"
    ln -sfT "$to" "$from"
done
packages="$(dpkg-query -W -f '.' | wc -c)"
if [ "$packages" -eq 0 ]; then
    echo "the relocated dpkg admindir answers for no packages at all" >&2
    exit 1
fi
echo "dpkg answers for ${packages} packages from /usr/lib/sysimage/dpkg"

# ---- what a build must not bake in ----
: > /etc/machine-id
find /run -mindepth 1 -maxdepth 1 ! -name secrets ! -name .containerenv \
    -exec rm -rf {} +

if getent passwd ubuntu > /dev/null; then
    userdel ubuntu
fi
rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*
rm -f /etc/fstab

rm -f /etc/systemd/system/multi-user.target.wants/ssh.service

if [ -x /usr/sbin/NetworkManager ]; then
    rm -f /usr/lib/systemd/network/89-ethernet.network
fi

rm -f /etc/dpkg/dpkg.cfg.d/docker-apt-speedup
rm -f /etc/apt/apt.conf.d/docker-clean \
    /etc/apt/apt.conf.d/docker-gzip-indexes \
    /etc/apt/apt.conf.d/docker-no-languages \
    /etc/apt/apt.conf.d/docker-autoremove-suggests

# ---- the ostree-shaped root ----
# shellcheck disable=SC2114 # replacing the system directories is the point
rm -rf /boot /home /root /srv /mnt /usr/local
mkdir -p /boot /sysroot /var/home /var/srv /var/mnt /var/usrlocal /var/roothome
chmod 0700 /var/roothome
ln -sT var/home /home
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT ../var/usrlocal /usr/local
ln -sT sysroot/ostree /ostree
