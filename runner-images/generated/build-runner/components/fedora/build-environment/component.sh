source /ctx/lib/family.sh
stash_systemctl

# The nodocs flag skips files at install time, so this layer reinstalls every package after removing it from dnf.conf.
if [ -f /etc/dnf/dnf.conf ] && grep -qx 'tsflags=nodocs' /etc/dnf/dnf.conf; then
    sed -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf
    mapfile -t installed < <(rpm -qa --qf '%{NAME}\n' | grep -vx gpg-pubkey)
    dnf -y reinstall "${installed[@]}"
fi

if command -v dnf5 > /dev/null; then
    dnf5 install -y dnf5-plugins
fi

stash_systemctl
