if [ -e /usr/bin/systemctl ] && [ ! -e /usr/bin/systemctl.bak ]; then
    mv /usr/bin/systemctl /usr/bin/systemctl.bak
    ln -s /usr/bin/true /usr/bin/systemctl
fi

if grep -qx 'tsflags=nodocs' /etc/dnf/dnf.conf 2> /dev/null; then
    sed -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf
    mapfile -t installed < <(rpm -qa --qf '%{NAME}\n' | grep -vx gpg-pubkey)
    dnf -y reinstall "${installed[@]}"
fi

if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi
