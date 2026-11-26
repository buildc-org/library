# Debian's administrators are in the sudo group, so pam_wheel checks that group instead of wheel.
sed -i 's/^#[[:space:]]*\(auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so\)$/\1 use_uid group=sudo/' /etc/pam.d/su
grep -qE '^auth[[:space:]]+required[[:space:]]+pam_wheel\.so use_uid group=sudo$' /etc/pam.d/su
