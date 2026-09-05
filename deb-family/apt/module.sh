if [ -f /etc/dpkg/dpkg.cfg.d/excludes ]; then
	rm -f /etc/dpkg/dpkg.cfg.d/excludes
	# shellcheck disable=SC2046 # one package name per line is the point
	DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y \
		$(dpkg-query -W -f '${binary:Package}\n')
fi

if [ -e /usr/sbin/policy-rc.d ]; then
	mv /usr/sbin/policy-rc.d /usr/sbin/policy-rc.d.bak
fi
printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
