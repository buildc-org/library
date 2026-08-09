[group('System')]
bios-info:
	#!/usr/bin/bash
	sudo bash <<'EOF'
	echo "Manufacturer: $(dmidecode -s baseboard-manufacturer)"
	echo "Product Name: $(dmidecode -s baseboard-product-name)"
	echo "Version: $(dmidecode -s bios-version)"
	echo "Release Date: $(dmidecode -s bios-release-date)"
	EOF

[group('System')]
check-idle-power-draw:
	#!/usr/bin/bash
	sudo powerstat -a -r

[group('Network')]
randomize-mac:
	#!/usr/bin/env bash
	set -eou pipefail

	ACTIVE=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')
	if [[ -z "$ACTIVE" ]]; then
		echo "No active Wi-Fi connection found."
		exit 1
	fi
	DEV=$(nmcli -t -f DEVICE,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')

	echo "==> Setting MAC randomization for: $ACTIVE"
	nmcli connection modify "$ACTIVE" wifi.cloned-mac-address random
	nmcli connection down "$ACTIVE"
	nmcli connection up "$ACTIVE"
	echo "Done. New MAC: $(ip link show "$DEV" | awk '/ether/{print $2}')"
