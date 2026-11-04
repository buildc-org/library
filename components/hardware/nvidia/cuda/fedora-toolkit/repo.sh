source /ctx/lib/nvidia-repo.sh

fedora="$(rpm -E %fedora)"
cuda_repo="cuda-fedora${fedora}-x86_64"
cuda_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-nvidia-cuda
setup_nvidia_rpm_repo "$cuda_repo" \
    "https://developer.download.nvidia.com/compute/cuda/repos/fedora${fedora}/x86_64/cuda-fedora${fedora}.repo" \
    "$ASSET_REPO_KEY_URL" "$ASSET_REPO_KEY_SHA256" "$cuda_key" 1
