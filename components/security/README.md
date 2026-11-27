# Security components

`apparmor` installs the AppArmor policy on Debian and Ubuntu.
`signature-policy` verifies image updates with cosign.

The group has no SELinux component yet.
The Fedora and RHEL bases provide the `selinux-policy` capability.
A component that owns the policy configuration is a known gap.
A firewall component is a known gap.
