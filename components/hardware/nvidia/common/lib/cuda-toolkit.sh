cuda_toolkit_package() {
    local version="$1"
    if [ "$version" = latest ]; then
        echo cuda-toolkit
    else
        echo "cuda-toolkit-${version//./-}"
    fi
}

link_cuda_toolkit() {
    local version="$1"
    local tree="/usr/local/cuda-${version}"
    if [ ! -x "${tree}/bin/nvcc" ]; then
        echo "no nvcc under ${tree} after installing the CUDA toolkit" >&2
        return 1
    fi
    if [ -d /usr/local/cuda ] && [ ! -L /usr/local/cuda ]; then
        echo "/usr/local/cuda is a directory, and this layer replaces it with a link" >&2
        return 1
    fi
    ln -sfn "$tree" /usr/local/cuda
}

install_cuda_toolkit_deb() {
    local version="$1" toolkit installed
    toolkit="$(cuda_toolkit_package "$version")"
    install_packages "$toolkit"
    installed="$(dpkg-query -W -f='${Version}' "$toolkit")"
    installed="${installed#*:}"
    # The toolkit tree is named after the package's major and minor version.
    link_cuda_toolkit "$(printf '%s\n' "$installed" | cut -d. -f1-2)"
}
