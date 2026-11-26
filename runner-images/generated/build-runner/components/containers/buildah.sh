#!/usr/bin/env bash
# GENERATED FILE, do not edit.
set -euxo pipefail

COMPONENT_DIR=/ctx/components/containers/buildah
export COMPONENT_DIR

source /ctx/lib/family.sh

dnf install -y 'buildah'
stash_systemctl

# ---- witness for buildah ----
if [ ! -e '/usr/bin/buildah' ]; then
    echo "component containers/buildah provides buildah, and its witness /usr/bin/buildah is missing" >&2
    exit 1
fi
