if [ -e /usr/bin/systemctl ] && [ ! -e /usr/bin/systemctl.bak ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
fi

sed -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf

if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
