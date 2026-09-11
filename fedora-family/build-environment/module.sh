source /ctx/lib/family.sh
stash_systemctl

if grep -qx 'tsflags=nodocs' /etc/dnf/dnf.conf 2> /dev/null; then
    sed -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf
    mapfile -t installed < <(rpm -qa --qf '%{NAME}\n' | grep -vx gpg-pubkey)
    dnf -y reinstall "${installed[@]}"
fi

if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi

stash_systemctl
