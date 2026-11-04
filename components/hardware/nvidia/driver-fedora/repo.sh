source /ctx/lib/nvidia-repo.sh

driver_key=/etc/pki/rpm-gpg/RPM-GPG-KEY-negativo17
setup_nvidia_rpm_repo "$NVIDIA_DRIVER_REPO" "$NVIDIA_DRIVER_REPO_FILE" \
    "$ASSET_DRIVER_KEY_URL" "$ASSET_DRIVER_KEY_SHA256" "$driver_key" 1
