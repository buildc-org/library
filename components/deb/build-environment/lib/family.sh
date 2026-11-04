#!/bin/bash

install_packages() {
    mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
    mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/info /var/lib/dpkg/triggers
    [ -f /var/lib/dpkg/status ] || : > /var/lib/dpkg/status
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

add_repo_source() {
    local id="$1" uri="$2" suite="$3" components="$4" signed_by="$5"
    printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: %s\nSigned-By: %s\n' \
        "$uri" "$suite" "$components" "$signed_by" > "/etc/apt/sources.list.d/$id.sources"
}

add_repo() {
    local id="$1" uri="$2" suite="$3" components="$4" key="$5"
    local at=/usr/share/keyrings ext=gpg

    command -v curl > /dev/null || install_packages curl ca-certificates
    install -d -m 0755 "$at"
    curl --retry 3 -fsSLo "$at/$id.key" "$key"
    if head -c 64 "$at/$id.key" | grep -qa "BEGIN PGP PUBLIC KEY"; then
        ext=asc
    fi
    mv "$at/$id.key" "$at/$id.$ext"

    add_repo_source "$id" "$uri" "$suite" "$components" "$at/$id.$ext"
}

# Some vendors ship the repository key as a .deb package, so this form verifies and extracts one.
add_repo_keyring() {
    local id="$1" uri="$2" suite="$3" components="$4" keyring_url="$5" keyring_sha="$6" member="$7"
    local at=/usr/share/keyrings tmp name ext

    command -v curl > /dev/null || install_packages curl ca-certificates
    install -d -m 0755 "$at"
    tmp="$(mktemp -d)"
    curl --retry 3 -fsSLo "$tmp/keyring.deb" "$keyring_url"
    echo "${keyring_sha}  ${tmp}/keyring.deb" | sha256sum -c -
    dpkg-deb -x "$tmp/keyring.deb" "$tmp/keyring"
    name="${member##*/}"
    ext="${name##*.}"
    install -D -m 0644 "$tmp/keyring/$member" "$at/$id.$ext"
    rm -rf "$tmp"

    add_repo_source "$id" "$uri" "$suite" "$components" "$at/$id.$ext"
}
