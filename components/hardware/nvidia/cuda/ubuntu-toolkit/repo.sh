source /ctx/lib/family.sh

add_repo_keyring "nvidia-cuda" \
    "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/" "/" "" \
    "$ASSET_CUDA_KEYRING_URL" "$ASSET_CUDA_KEYRING_SHA256" \
    "usr/share/keyrings/cuda-archive-keyring.gpg"
