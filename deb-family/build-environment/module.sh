mkdir -p /etc/apt/tect-build
for sources in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/debian.sources; do
    [ -f "$sources" ] || continue
    cp -p "$sources" /etc/apt/tect-build/
    sed -i -e 's|http://archive.ubuntu.com/|http://azure.archive.ubuntu.com/|' \
        -e 's|http://deb.debian.org/|http://debian-archive.trafficmanager.net/|' "$sources"
done
printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\n' > /etc/apt/apt.conf.d/80-tect-build

if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
    rm -f /etc/dpkg/dpkg.cfg.d/excludes
    mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/log/apt
    DEBIAN_FRONTEND=noninteractive apt-get update
    # shellcheck disable=SC2046 # one package name per line is the point
    DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y \
        $(dpkg-query -W -f '${binary:Package}\n')
    compgen -G '/usr/share/man/man1/*' > /dev/null || {
        echo "build-environment: the path-exclude repair restored no man pages" >&2
        exit 1
    }
fi

if [ -e /usr/sbin/policy-rc.d ]; then
    mv /usr/sbin/policy-rc.d /usr/sbin/policy-rc.d.bak
fi
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
