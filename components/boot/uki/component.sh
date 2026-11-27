source /ctx/lib/sign-helpers.sh

case "$OPT_TRUST" in
    shim | db) ;;
    *)
        echo "boot/uki: option \"trust\" is \"$OPT_TRUST\". Set the option to \"shim\" or \"db\"." >&2
        exit 1
        ;;
esac

openssl x509 -in "$MOK_CERT_DER" -inform DER \
    -out /usr/share/secureboot/sb_cert.pem -outform PEM
if mok_signing_available; then
    sign_vmlinuz /usr/lib/systemd/boot/efi/systemd-bootx64.efi
    install -D -m 0644 /dev/null /usr/share/secureboot/signed
else
    echo "No MOK key supplied, systemd-boot is unsigned."
fi

if [ -s /run/secrets/pcr_privkey ]; then
    if ! openssl pkey -pubout -in /run/secrets/pcr_privkey \
        | cmp -s - /usr/share/secureboot/pcr.pub; then
        echo "the PCR private key does not match /usr/share/secureboot/pcr.pub" >&2
        exit 1
    fi
    install -D -m 0644 /usr/share/secureboot/pcr.pub \
        /usr/share/secureboot/pcr-policy.pem
else
    echo "No PCR signing key supplied, the image carries no PCR policy."
fi

install -D -m 0644 /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    /boot/EFI/systemd/systemd-bootx64.efi
install -D -m 0644 /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    /boot/EFI/BOOT/BOOTX64.EFI
install -D -m 0644 "$COMPONENT_DIR/canary/digest" \
    /usr/share/buildc/composefs-canary-digest
bootc --version > /usr/share/buildc/composefs-sealer-version
printf 'uki-%s\n' "$OPT_TRUST" > /usr/share/buildc/boot-chain

rm -rf /usr/lib/efi/grub2
dnf5 -y remove --noautoremove bootupd

case "$OPT_TRUST" in
    shim)
        install -D -m 0755 "$COMPONENT_DIR/install-shim.sh" \
            /usr/libexec/secureboot-enrolment
        ;;
    db)
        if ! mok_signing_available; then
            echo "No MOK key was supplied. The image carries no firmware enrolment keys."
            exit 0
        fi

        work=$(mktemp -d)
        openssl x509 -in "$MOK_CERT_DER" -inform DER \
            -out "$work/secureboot.pem" -outform PEM
        guid=$(uuidgen)
        for name in PK KEK db; do
            cert-to-efi-sig-list -g "$guid" "$work/secureboot.pem" "$work/$name.esl"
            sign-efi-sig-list -g "$guid" -k "$MOK_KEY" -c "$work/secureboot.pem" \
                "$name" "$work/$name.esl" "$work/$name.auth"
            install -D -m 0644 "$work/$name.auth" \
                "/usr/lib/bootc/install/secureboot-keys/auto/$name.auth"
        done
        rm -rf "$work"
        ;;
esac
