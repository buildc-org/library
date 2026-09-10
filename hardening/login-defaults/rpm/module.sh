sed -i 's/\bumask 0\?22\b/umask 027/g' /etc/bashrc
grep -qE '^[[:space:]]*umask[[:space:]]' /etc/bashrc || printf 'umask 027\n' >> /etc/bashrc
