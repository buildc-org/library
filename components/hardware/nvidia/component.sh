source /ctx/lib/family.sh
source /ctx/lib/fetch-helpers.sh
source /ctx/lib/kernel-helpers.sh
source /ctx/lib/sign-helpers.sh
source /usr/libexec/kernel-devel-helpers.sh

fedora="$(rpm -E %fedora)"
REPO_ID="cuda-fedora${fedora}-x86_64"
key=/etc/pki/rpm-gpg/RPM-GPG-KEY-nvidia-cuda
fetch_verified "$ASSET_REPO_KEY_URL" "$ASSET_REPO_KEY_SHA256" "$key"
rpm --import "$key"
if [ ! -f "/etc/yum.repos.d/cuda-fedora${fedora}.repo" ]; then
    add_disabled_repo "https://developer.download.nvidia.com/compute/cuda/repos/fedora${fedora}/x86_64/cuda-fedora${fedora}.repo"
fi
dnf5 config-manager setopt "${REPO_ID}.gpgkey=file://${key}"
dnf5 config-manager setopt "${REPO_ID}.priority=1"
info="$(dnf5 -q repo info --enablerepo="$REPO_ID" "$REPO_ID")"
if ! grep -qE "^ *Keys *: file://${key}\$" <<< "$info"; then
    echo "${REPO_ID} does not name ${key} as its only key after setopt" >&2
    exit 1
fi
if ! grep -qE '^Priority *: 1$' <<< "$info"; then
    echo "${REPO_ID} does not carry priority 1 after setopt" >&2
    exit 1
fi
repo=(--enablerepo="$REPO_ID")

want=nvidia-kmod-common
if [ "$OPT_VERSION" != latest ]; then
    want="nvidia-kmod-common-${OPT_VERSION}"
fi
evr="$(dnf5 repoquery -q --repo="$REPO_ID" --latest-limit=1 --qf '%{epoch}:%{version}-%{release}\n' "$want")"
if [ -z "$evr" ]; then
    echo "no ${want} in ${REPO_ID}" >&2
    exit 1
fi
vr="${evr#*:}"

need=(rpm-build)
if [ "$OPT_KERNEL_MODULES" = 1 ]; then
    need+=(cpio gcc gcc-c++ make elfutils-libelf-devel)
fi
tools=()
for p in "${need[@]}"; do
    rpm -q "$p" > /dev/null || tools+=("$p")
done
if [ ${#tools[@]} -gt 0 ]; then
    dnf5 install -y "${tools[@]}"
fi

stub=/tmp/nvidia-kmod-stub
mkdir -p "$stub"
cat > "$stub/nvidia-kmod.spec" << SPEC
Name: nvidia-kmod
Epoch: ${evr%%:*}
Version: ${vr%%-*}
Release: ${vr#*-}
Summary: Empty stand-in for the NVIDIA kernel modules the image builds
License: Apache-2.0
BuildArch: noarch
%description
Satisfies nvidia-kmod-common's requirement on nvidia-kmod. The image builds
the NVIDIA kernel modules for its own kernel.
%files
SPEC
rpmbuild -bb --define "_topdir ${stub}" "$stub/nvidia-kmod.spec"
dnf5 install -y "$stub"/RPMS/noarch/nvidia-kmod-*.rpm
rm -rf "$stub"

packages=(
    nvidia-kmod-common nvidia-driver nvidia-driver-libs nvidia-driver-cuda
    nvidia-modprobe nvidia-settings libnvidia-fbc
)
nevras=("${packages[@]/%/-${vr}}" "nvidia-driver-libs-${vr}.i686")
dnf5 install -y "${repo[@]}" --setopt=install_weak_deps=False "${nevras[@]}"
dnf5 install -y libva-nvidia-driver

if [ "$OPT_KERNEL_MODULES" = 1 ]; then
    kver="$(kver)"
    kernel_devel_install
    src=/tmp/nvidia-open
    dnf5 download --repo="$REPO_ID" --destdir="$src" "kmod-nvidia-open-dkms-${vr}"
    (cd "$src" && rpm2cpio ./*.rpm | cpio -idm --quiet)
    tree="$(find "$src/usr/src" -maxdepth 1 -type d -name 'nvidia-*' | head -1)"
    if [ -z "$tree" ]; then
        echo "no driver source under ${src}/usr/src in kmod-nvidia-open-dkms-${vr}" >&2
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
fi

if [ ${#tools[@]} -gt 0 ]; then
    dnf5 remove -y --noautoremove "${tools[@]}"
fi
