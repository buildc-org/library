#!/usr/bin/env bash
# GENERATED FILE, do not edit.
set -euxo pipefail

COMPONENT_DIR=/ctx/components/containers/podman
export COMPONENT_DIR

source /ctx/lib/family.sh

dnf install -y 'podman'
stash_systemctl

# ---- witness for podman ----
if [ ! -e '/usr/bin/podman' ]; then
    echo "component containers/podman provides podman, and its witness /usr/bin/podman is missing" >&2
    exit 1
fi
