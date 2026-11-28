#!/usr/bin/env bash
# GENERATED FILE, do not edit.
set -euxo pipefail

COMPONENT_DIR=/ctx/components/container-environment/runtime/podman
export COMPONENT_DIR

source /ctx/lib/family.sh

dnf install -y 'podman'
stash_systemctl

# ---- witness for podman ----
if [ ! -e '/usr/bin/podman' ]; then
    echo "component container-environment/runtime/podman provides podman, and its witness /usr/bin/podman is missing" >&2
    exit 1
fi

# ---- witness for crun ----
if [ ! -e '/usr/bin/crun' ]; then
    echo "component container-environment/runtime/podman provides crun, and its witness /usr/bin/crun is missing" >&2
    exit 1
fi
