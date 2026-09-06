#!/bin/bash

install_packages() {
	mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
	mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/info /var/lib/dpkg/triggers
	[ -f /var/lib/dpkg/status ] || : > /var/lib/dpkg/status
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
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

	cat >"/etc/apt/sources.list.d/$id.sources" <<-EOF
		Types: deb
		URIs: $uri
		Suites: $suite
		Components: $components
		Signed-By: $at/$id.$ext
	EOF
}
