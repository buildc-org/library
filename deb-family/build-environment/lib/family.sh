#!/bin/bash

install_packages() {
	mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
	mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/info /var/lib/dpkg/triggers
	[ -f /var/lib/dpkg/status ] || : > /var/lib/dpkg/status
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
