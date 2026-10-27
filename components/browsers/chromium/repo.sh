cat > /etc/apt/sources.list.d/debian-sid.sources << 'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: sid
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOF

# A pin of 1 keeps sid out of ordinary installs, while the chromium set at 990 overrides the base image's packages.
cat > /etc/apt/preferences.d/debian-sid << 'EOF'
Package: *
Pin: release n=sid
Pin-Priority: 1

Package: chromium chromium-common chromium-sandbox chromium-l10n chromium-driver
Pin: release n=sid
Pin-Priority: 990
EOF
