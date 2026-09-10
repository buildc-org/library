#!/bin/bash

install_packages() {
	local args=()
	if [ -n "${BUILDC_ENABLE_REPO:-}" ]; then
		args+=(--enablerepo="$BUILDC_ENABLE_REPO")
	fi
	dnf install -y "${args[@]}" "$@"
}

install_groups() {
	local args=()
	if [ -n "${BUILDC_ENABLE_REPO:-}" ]; then
		args+=(--enablerepo="$BUILDC_ENABLE_REPO")
	fi
	dnf group install -y "${args[@]}" "$@"
}

enable_copr() {
	dnf5 -y copr enable "$1"
	dnf5 -y copr disable "$1"
}

add_disabled_repo() {
	dnf5 config-manager addrepo --from-repofile="$1"
	dnf5 config-manager setopt "${REPO_ID:?add_disabled_repo needs REPO_ID set}.enabled=0"
}
