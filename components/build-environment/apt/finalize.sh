rm /usr/sbin/policy-rc.d
if [ -e /usr/sbin/policy-rc.d.bak ]; then
    mv /usr/sbin/policy-rc.d.bak /usr/sbin/policy-rc.d
fi

if [ -d /etc/apt/buildc-build ]; then
    # The base may carry neither ubuntu.sources nor debian.sources, so the glob can match nothing here.
    mv /etc/apt/buildc-build/*.sources /etc/apt/sources.list.d/ 2> /dev/null || true
    rmdir /etc/apt/buildc-build
fi
rm -f /etc/apt/apt.conf.d/80-buildc-build
