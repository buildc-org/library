mv /usr/bin/systemctl /usr/bin/systemctl.bak
ln -s /usr/bin/true /usr/bin/systemctl

if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
