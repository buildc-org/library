sed -i 's/\bumask 0\?22\b/umask 027/g' /etc/bash.bashrc
grep -qE '^[[:space:]]*umask[[:space:]]' /etc/bash.bashrc || printf 'umask 027\n' >> /etc/bash.bashrc
