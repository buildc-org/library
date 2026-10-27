mkdir -p /usr/lib/systemd/system-preset

for unit in plasmalogin.service plasma-setup.service sddm.service \
    input-remapper.service input-remapper-daemon.service; do
    if [ -f "/usr/lib/systemd/system/${unit}" ]; then
        echo "enable ${unit}"
    fi
done > /usr/lib/systemd/system-preset/45-component-kde-desktop-variants.preset
