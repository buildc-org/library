pam-auth-update --package
grep -q 'pam_faillock.so preauth' /etc/pam.d/common-auth
grep -q 'pam_faillock.so authfail' /etc/pam.d/common-auth
grep -q 'pam_faillock.so authsucc' /etc/pam.d/common-auth
grep -q 'pam_faillock.so' /etc/pam.d/common-account
grep -q 'pam_pwquality.so' /etc/pam.d/common-password

install -d /usr/share/cracklib
create-cracklib-dict -o /usr/share/cracklib/pw_dict /usr/share/dict/cracklib-small
printf 'dictpath = /usr/share/cracklib/pw_dict\n' >> /etc/security/pwquality.conf
