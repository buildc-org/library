# shellcheck disable=SC2034  # the repository constants are consumed by the repo, packages and module scripts
source /ctx/lib/fetch-helpers.sh

NVIDIA_DRIVER_REPO="fedora-nvidia"
NVIDIA_DRIVER_REPO_FILE="https://negativo17.org/repos/fedora-nvidia.repo"

setup_nvidia_rpm_repo() {
    local repo_id="$1" repo_file="$2" key_url="$3" key_sha="$4" key_path="$5" priority="$6"
    local added=0 info repo_file_name="${repo_file##*/}"
    if [ ! -f "/etc/yum.repos.d/${repo_file_name}" ]; then
        dnf5 config-manager addrepo --from-repofile="$repo_file"
        added=1
    fi
    # Keep an enabled state that the base image already set for this repository.
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
