FROM rootfs AS kernel-split
RUN mkdir /kernel && \
    bootc container split-kernel-and-rootfs --rootfs / --output /kernel

FROM ${SPLIT_BASE} AS split

FROM split AS sealed-uki
ARG COMPOSEFS_DIGEST
RUN --mount=type=bind,from=split,target=/target \
    --mount=type=bind,from=split,source=/kernel,target=/kernel \
    --mount=type=bind,from=ctx,source=@MODULE@/canary,target=/canary,ro \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    --mount=type=secret,id=pcr_privkey,target=/run/secrets/pcr_privkey,required=false \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,target=/tmp <<'SH'
set -euxo pipefail

# The canary pins the composefs digest of a fixed root.
# The build stops when the installed bootc computes a different digest.
expected=$(cat /canary/digest)
expected_version=$(cat /canary/bootc-version)
cp -a /canary/root /tmp/canary
mkdir -p /tmp/canary/boot /tmp/canary/sysroot
# The composefs digest covers file metadata, so permissions and timestamps are normalized before hashing.
find /tmp/canary -type d -exec chmod 0755 {} +
find /tmp/canary -type f -exec chmod 0644 {} +
find /tmp/canary -exec touch -h -d @0 {} +
actual=$(bootc container compute-composefs-digest /tmp/canary)
actual_version=$(bootc --version)
if [ "$actual" != "$expected" ]; then
    echo "composefs digest canary moved: $expected ($expected_version) -> $actual ($actual_version)" >&2
    exit 1
fi

test -n "$COMPOSEFS_DIGEST" || {
    echo "COMPOSEFS_DIGEST is empty; build this image with \`tect build\`, which computes it" >&2
    exit 1
}
mkdir -p /out
kver=$(ls /kernel)
sign=()
if [ -s /run/secrets/mok_privkey ]; then
    openssl x509 -in /usr/share/secureboot/sb_cert.der -inform DER \
        -out /tmp/secureboot.pem -outform PEM
    sign=(
        --signtool sbsign
        --secureboot-private-key /run/secrets/mok_privkey
        --secureboot-certificate /tmp/secureboot.pem
    )
else
    echo "No MOK key supplied, UKI is unsigned."
fi

pcr=()
if [ -s /run/secrets/pcr_privkey ]; then
    pcr=(
        --pcr-private-key /run/secrets/pcr_privkey
        --pcr-public-key /usr/share/secureboot/pcr.pub
    )
else
    echo "No PCR signing key supplied, the UKI carries no PCR policy."
fi

# The first ukify run assembles the cmdline bootc generates.
# The composefs digest is swapped into that cmdline before the real UKI is built.
bootc container ukify \
    --rootfs /target \
    --kernel-dir "/kernel/${kver}" \
    -- \
    --output /probe.efi
cmdline=$(objcopy -O binary --only-section=.cmdline /probe.efi /dev/stdout | tr -d '\0')
sealed=$(echo "$cmdline" | sed -E "s/composefs=[0-9a-f?]+/composefs=${COMPOSEFS_DIGEST}/")
case "$sealed" in
    *"composefs=${COMPOSEFS_DIGEST}"*) ;;
    *)
        echo "the assembled cmdline carries no composefs= karg to seal" >&2
        exit 1
        ;;
esac

bootc container ukify \
    --rootfs /target \
    --kernel-dir "/kernel/${kver}" \
    -- \
    --output "/out/${kver}.efi" \
    --cmdline "$sealed" \
    "${sign[@]}" "${pcr[@]}"
SH

FROM split
COPY --from=sealed-uki /out/*.efi /boot/EFI/Linux/
