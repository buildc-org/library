# On Debian the driver and the toolkit come from this archive. On Ubuntu only the toolkit does. A later apt-get upgrade must not move the toolkit.
if [ -f /etc/apt/sources.list.d/nvidia-cuda.sources ]; then
    if ! grep -qx 'Enabled: no' /etc/apt/sources.list.d/nvidia-cuda.sources; then
        printf 'Enabled: no\n' >> /etc/apt/sources.list.d/nvidia-cuda.sources
    fi
    grep -qx 'Enabled: no' /etc/apt/sources.list.d/nvidia-cuda.sources
fi
