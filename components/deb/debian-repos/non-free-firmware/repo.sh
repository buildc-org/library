sources=/etc/apt/sources.list.d/debian.sources
if [ ! -f "$sources" ]; then
    echo "no $sources: this base does not configure apt the way debian:forky does" >&2
    exit 1
fi
sed -i '/^Components:/ { /non-free-firmware/! s/$/ non-free-firmware/ }' "$sources"
grep -q 'non-free-firmware' "$sources"
