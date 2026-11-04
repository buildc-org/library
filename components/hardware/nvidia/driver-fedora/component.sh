source /ctx/lib/family.sh
source /ctx/lib/kernel-helpers.sh
source /ctx/lib/sign-helpers.sh
source /ctx/lib/nvidia-repo.sh
source /usr/libexec/kernel-devel-helpers.sh

if [ "$OPT_KERNEL_MODULES" != build ]; then
    exit 0
fi

evr="$(rpm -q --qf '%{epoch}:%{version}-%{release}\n' nvidia-kmod-common)"
vr="${evr#*:}"
version="${vr%%-*}"

need=(cpio gcc gcc-c++ make elfutils-libelf-devel)
tools=()
for p in "${need[@]}"; do
    rpm -q "$p" > /dev/null || tools+=("$p")
done
if [ ${#tools[@]} -gt 0 ]; then
    dnf5 install -y "${tools[@]}"
fi

kver="$(kver)"
kernel_devel_install
src=/tmp/nvidia-dkms
dnf5 download --repo="$NVIDIA_DRIVER_REPO" --destdir="$src" "dkms-nvidia-${version}"
(cd "$src" && rpm2cpio ./*.rpm | cpio -idm --quiet)
tree="$(find "$src/usr/src" -maxdepth 1 -type d -name 'nvidia-*' -print -quit)"
if [ -z "$tree" ]; then
    echo "no driver source under ${src}/usr/src in dkms-nvidia-${version}" >&2
    exit 1
fi
make -C "$tree" modules -j"$(nproc)" KERNEL_UNAME="$kver"
install -d "/usr/lib/modules/${kver}/extra/nvidia"
install -m 0644 "$tree"/kernel-open/*.ko "/usr/lib/modules/${kver}/extra/nvidia/"
depmod -a "$kver"
if mok_signing_available; then
    sign_modules_under "/usr/lib/modules/${kver}/extra/nvidia" "/usr/src/kernels/${kver}/scripts/sign-file"
else
    echo "No MOK key supplied, so the NVIDIA modules are unsigned and Secure Boot will not load them."
fi
rm -rf "$src"
kernel_devel_remove

if [ ${#tools[@]} -gt 0 ]; then
    dnf5 remove -y --noautoremove "${tools[@]}"
fi
