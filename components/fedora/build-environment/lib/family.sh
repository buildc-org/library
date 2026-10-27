#!/bin/bash

stash_systemctl() {
    [ -e /usr/bin/systemctl ] || return 0
    [ "$(readlink /usr/bin/systemctl)" = /usr/bin/true ] && return 0
    mv -f /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
}

install_packages() {
    local args=()
    if [ -n "${BUILDC_ENABLE_REPO:-}" ]; then
        args+=(--enablerepo="$BUILDC_ENABLE_REPO")
    fi
    dnf install -y "${args[@]}" "$@"
    # An upgrade of systemd puts the real systemctl binary back, so the stub is re-applied after every install.
    stash_systemctl
}

install_groups() {
    local args=()
    if [ -n "${BUILDC_ENABLE_REPO:-}" ]; then
        args+=(--enablerepo="$BUILDC_ENABLE_REPO")
    fi
    dnf group install -y "${args[@]}" "$@"
    stash_systemctl
}

enable_copr() {
    dnf5 -y copr enable "$1"
    dnf5 -y copr disable "$1"
}

add_disabled_repo() {
    dnf5 config-manager addrepo --from-repofile="$1"
    dnf5 config-manager setopt "${REPO_ID:?add_disabled_repo needs REPO_ID set}.enabled=0"
}
