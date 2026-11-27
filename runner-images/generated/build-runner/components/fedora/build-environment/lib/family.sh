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

# This form pins the key and priority, and it keeps an enabled state that the base image already set.
add_pinned_repo() {
    local repo_id="$1" repo_file="$2" key_url="$3" key_sha="$4" key_path="$5" priority="$6"
    local added=0 info repo_file_name="${repo_file##*/}"

    source /ctx/lib/fetch-helpers.sh
    if [ ! -f "/etc/yum.repos.d/${repo_file_name}" ]; then
        dnf5 config-manager addrepo --from-repofile="$repo_file"
        added=1
    fi
    if [ "$added" = 1 ]; then
        dnf5 config-manager setopt "${repo_id}.enabled=0"
    fi
    fetch_verified "$key_url" "$key_sha" "$key_path"
    rpm --import "$key_path"
    dnf5 config-manager setopt "${repo_id}.gpgkey=file://${key_path}"
    dnf5 config-manager setopt "${repo_id}.priority=${priority}"
    info="$(dnf5 -q repo info --enablerepo="$repo_id" "$repo_id")"
    if ! grep -qE "^ *Keys *: file://${key_path}\$" <<< "$info"; then
        echo "${repo_id} does not name ${key_path} as its only key after setopt" >&2
        return 1
    fi
    if ! grep -qE "^Priority *: ${priority}\$" <<< "$info"; then
        echo "${repo_id} does not carry priority ${priority} after setopt" >&2
        return 1
    fi
}
