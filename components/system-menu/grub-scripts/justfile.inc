# Regenerate grub.cfg with os-prober to add other installed OSes to the boot menu
[group('System')]
regenerate-grub:
	sudo /usr/libexec/grub2-os-prober-regen
