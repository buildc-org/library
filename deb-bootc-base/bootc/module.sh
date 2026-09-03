source /ctx/lib/fetch-helpers.sh

NEEDS_OSTREE=2025.3
HAS_OSTREE="$(dpkg-query -W -f '${Version}' libostree-1-1)"
if ! dpkg --compare-versions "$HAS_OSTREE" ge "$NEEDS_OSTREE"; then
	echo "this base carries libostree ${HAS_OSTREE}, and bootc" \
		"${ASSET_BOOTC_VERSION} needs >= ${NEEDS_OSTREE}" >&2
	exit 1
fi

BUILD_DEPS=(
	build-essential rustc cargo
	libostree-dev libzstd-dev libssl-dev pkgconf go-md2man
)
install_packages "${BUILD_DEPS[@]}"

if [ "$ASSET_BOOTC_VERSION" != "$ASSET_BOOTC_VENDOR_VERSION" ]; then
	echo "bootc is pinned at ${ASSET_BOOTC_VERSION} and its vendor tarball at" \
		"${ASSET_BOOTC_VENDOR_VERSION}; both pins move together" >&2
	exit 1
fi

src=/tmp/bootc
fetch_extract "$ASSET_BOOTC_URL" "$ASSET_BOOTC_SHA256" "$src"
cd "${src}/bootc-${ASSET_BOOTC_VERSION}" || exit

fetch_extract "$ASSET_BOOTC_VENDOR_URL" "$ASSET_BOOTC_VENDOR_SHA256" .
cat .cargo/vendor-config.toml >>.cargo/config.toml

export CARGO_NET_OFFLINE=true
export CARGO_BUILD_LOCKED=true

export CARGO_PROFILE_RELEASE_DEBUG=false
export CARGO_PROFILE_RELEASE_STRIP=true

make bin install DESTDIR=/
ldconfig
bootc --version

cd /
rm -rf "$src"

# ---- bootupd, and the signed chain it installs ----
if [ "$ASSET_BOOTUPD_VERSION" != "$ASSET_BOOTUPD_VENDOR_VERSION" ]; then
	echo "bootupd is pinned at ${ASSET_BOOTUPD_VERSION} and its vendor tarball" \
		"at ${ASSET_BOOTUPD_VENDOR_VERSION}; both pins move together" >&2
	exit 1
fi

src=/tmp/bootupd
fetch_extract "$ASSET_BOOTUPD_URL" "$ASSET_BOOTUPD_SHA256" "$src"
cd "${src}/bootupd-${ASSET_BOOTUPD_VERSION}" || exit
fetch_extract "$ASSET_BOOTUPD_VENDOR_URL" "$ASSET_BOOTUPD_VENDOR_SHA256" .

mkdir -p .cargo
cat >>.cargo/config.toml <<'CARGO'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CARGO

make all install install-grub-static DESTDIR=/ PREFIX=/usr LIBEXECDIR=/usr/libexec
bootupctl --version

rm -f /usr/lib/bootupd/grub2-static/configs.d/10_blscfg.cfg

ln -sf grub-editenv /usr/bin/grub2-editenv

vendor="$(. /etc/os-release && echo "$ID")"
shim_dir="/usr/lib/efi/shim/$(dpkg-query -W -f '${Version}' shim-signed)/EFI"
grub_dir="/usr/lib/efi/grub2/$(dpkg-query -W -f '${Version}' grub-efi-amd64-signed)/EFI"

install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/${vendor}/shimx64.efi"
install -D -m 0644 /usr/lib/shim/shimx64.efi.signed "${shim_dir}/BOOT/BOOTX64.EFI"
install -D -m 0644 /usr/lib/shim/fbx64.efi.signed "${shim_dir}/BOOT/fbx64.efi"
if [ -f /usr/lib/shim/mmx64.efi.signed ]; then
	install -D -m 0644 /usr/lib/shim/mmx64.efi.signed "${shim_dir}/${vendor}/mmx64.efi"
fi
install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
	"${grub_dir}/${vendor}/grubx64.efi"

install -D -m 0644 /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed \
	"${shim_dir}/BOOT/grubx64.efi"
install -D -m 0644 /usr/lib/shim/BOOTX64.CSV "${shim_dir}/${vendor}/BOOTX64.CSV"

install -D -m 0644 src/grub2/grub-static-efi.cfg "${grub_dir}/${vendor}/grub.cfg"

bootupctl backend generate-update-metadata /

cd /
rm -rf "$src"

DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
