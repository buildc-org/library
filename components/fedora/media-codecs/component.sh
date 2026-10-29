if [ ! -f /etc/yum.repos.d/fedora-multimedia.repo ]; then
    dnf5 install -y mesa-libOpenCL.x86_64
fi

rm -f /usr/share/pipewire/pipewire.conf.d/50-raop.conf
