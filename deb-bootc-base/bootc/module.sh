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
DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
