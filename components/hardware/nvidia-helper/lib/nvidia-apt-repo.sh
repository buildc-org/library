setup_nvidia_apt_repo() {
    local keyring_url="$1" keyring_sha="$2" repo_url="$3"
    source /ctx/lib/family.sh
    command -v curl > /dev/null || install_packages curl ca-certificates
    local keyring=/tmp/cuda-keyring.deb
    curl --retry 3 -fsSLo "$keyring" "$keyring_url"
    echo "${keyring_sha}  ${keyring}" | sha256sum -c -
    rm -rf /tmp/cuda-keyring
    dpkg-deb -x "$keyring" /tmp/cuda-keyring
    install -D -m 0644 /tmp/cuda-keyring/usr/share/keyrings/cuda-archive-keyring.gpg \
        /usr/share/keyrings/nvidia-cuda.gpg
    rm -rf /tmp/cuda-keyring "$keyring"
    cat > /etc/apt/sources.list.d/nvidia-cuda.sources << EOF
Types: deb
URIs: ${repo_url}
Suites: /
Components:
Signed-By: /usr/share/keyrings/nvidia-cuda.gpg
EOF
}
