# shellcheck disable=SC2154  # NVIDIA_DRIVER_REPO is set by repo.sh, which the package step sources first
driver_repo="$NVIDIA_DRIVER_REPO"

want=nvidia-kmod-common
if [ "$OPT_VERSION" != latest ]; then
    want="nvidia-kmod-common-${OPT_VERSION}"
fi
evr="$(dnf5 repoquery -q --repo="$driver_repo" --latest-limit=1 --qf '%{epoch}:%{version}-%{release}\n' "$want")"
if [ -z "$evr" ]; then
    echo "no ${want} in ${driver_repo}" >&2
    exit 1
fi
vr="${evr#*:}"
version="${vr%%-*}"

tools=()
rpm -q rpm-build > /dev/null || tools+=(rpm-build)
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
i686="$(dnf5 repoquery -q --repo="$driver_repo" --arch=i686 --latest-limit=1 --qf '%{version}-%{release}\n' "nvidia-driver-libs-${version}")"
if [ -z "$i686" ]; then
    echo "no i686 nvidia-driver-libs-${version} in ${driver_repo}" >&2
    exit 1
fi
nevras=("${packages[@]/%/-${version}}" "nvidia-driver-libs-${i686}.i686")
dnf5 install -y --enablerepo="$driver_repo" --setopt=install_weak_deps=False "${nevras[@]}"
dnf5 install -y libva-nvidia-driver

if [ ${#tools[@]} -gt 0 ]; then
    dnf5 remove -y --noautoremove "${tools[@]}"
fi
