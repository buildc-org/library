source /ctx/lib/nvidia-apt-repo.sh

setup_nvidia_apt_repo "$ASSET_CUDA_KEYRING_URL" "$ASSET_CUDA_KEYRING_SHA256" \
    "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/"
