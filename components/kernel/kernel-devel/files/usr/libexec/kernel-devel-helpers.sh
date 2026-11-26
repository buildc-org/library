#!/bin/bash

source /ctx/lib/kernel-helpers.sh

KERNEL_DEVEL_PKG=kernel-devel-matched
KERNEL_DEVEL_REPO=()
if [ -f /usr/lib/kernel-build/kernel-devel-package ]; then
    KERNEL_DEVEL_PKG="$(cat /usr/lib/kernel-build/kernel-devel-package)"
elif [ -f /usr/lib/kernel-build/kernel-package ] \
    && [ "$(cat /usr/lib/kernel-build/kernel-package)" != kernel-core ]; then
    echo "/usr/lib/kernel-build/kernel-package names $(cat /usr/lib/kernel-build/kernel-package), but no component wrote /usr/lib/kernel-build/kernel-devel-package" >&2
    exit 1
fi
if [ -f /usr/lib/kernel-build/kernel-devel-repo ]; then
    KERNEL_DEVEL_REPO=(--enablerepo="$(cat /usr/lib/kernel-build/kernel-devel-repo)")
fi

kernel_devel_install() {
    dnf5 -y install "${KERNEL_DEVEL_REPO[@]}" "${KERNEL_DEVEL_PKG}-$(kver)" "$@"
}

kernel_devel_remove() {
    dnf5 -y remove --noautoremove "$KERNEL_DEVEL_PKG" "$@"
}
