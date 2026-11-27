#!/usr/bin/env bash
set -euxo pipefail

source /ctx/lib/family.sh
source /ctx/lib/fetch-helpers.sh

DEST="${DESTDIR:-/}"
DEST="${DEST%/}"

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
cat .cargo/vendor-config.toml >> .cargo/config.toml

export CARGO_NET_OFFLINE=true
export CARGO_BUILD_LOCKED=true

export CARGO_PROFILE_RELEASE_DEBUG=false
export CARGO_PROFILE_RELEASE_STRIP=true

make bin install DESTDIR="${DEST:-/}"
"${DEST}/usr/bin/bootc" --version

cd /
rm -rf "$src"

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
cat >> .cargo/config.toml << 'CARGO'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CARGO

make all install install-grub-static DESTDIR="${DEST:-/}" PREFIX=/usr LIBEXECDIR=/usr/libexec
"${DEST}/usr/bin/bootupctl" --version

rm -f "${DEST}/usr/lib/bootupd/grub2-static/configs.d/10_blscfg.cfg"

# bootupd calls grub2-editenv, which Debian's grub package does not provide under that name.
ln -sf grub-editenv "${DEST}/usr/bin/grub2-editenv"

cd /
rm -rf "$src"

DEBIAN_FRONTEND=noninteractive apt-get purge -y "${BUILD_DEPS[@]}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge
