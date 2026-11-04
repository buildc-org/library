source /ctx/lib/cuda-toolkit.sh

# shellcheck disable=SC2154  # cuda_repo is set by repo.sh, which the package step sources first
dnf5 install -y --enablerepo="$cuda_repo" --setopt=install_weak_deps=False \
    "$(cuda_toolkit_package "$OPT_VERSION")"
