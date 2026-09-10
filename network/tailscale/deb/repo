source /ctx/lib/family.sh

. /etc/os-release
add_repo "tailscale" \
    "https://pkgs.tailscale.com/stable/${ID}" "$VERSION_CODENAME" "main" \
    "https://pkgs.tailscale.com/stable/${ID}/${VERSION_CODENAME}.noarmor.gpg"
