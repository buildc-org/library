if [ -z "${CONFORMS:-}" ] || [ -z "${SCAP_CONTENT:-}" ]; then
    echo "scap-remediation: no conforms, nothing to remediate"
else
    dnf -y install openscap-utils scap-security-guide openscap-engine-sce setools-console

    scap_exempt="${SCAP_REFUSED:-}"
    if [ -n "${SCAP_CLAIMED:-}" ]; then
        # shellcheck disable=SC2086 # one number per argument is the point
        scap_exempt="${scap_exempt} $(/ctx/tect scap rules \
            --datastream "${SCAP_CONTENT}" ${SCAP_CLAIMED})"
    fi

    scap_profile="${CONFORMS}"
    scap_tailoring=()
    scap_unselect=()
    for scap_rule in ${scap_exempt}; do
        scap_unselect+=(-u "${scap_rule}")
    done
    if [ "${#scap_unselect[@]}" -gt 0 ]; then
        autotailor "${SCAP_CONTENT}" "${CONFORMS}" "${scap_unselect[@]}" \
            -p "${CONFORMS}_tect" -o /tmp/tect-tailoring.xml
        scap_profile="${CONFORMS}_tect"
        scap_tailoring=(--tailoring-file /tmp/tect-tailoring.xml)
        echo "scap-remediation: ${#scap_unselect[@]} rules left to their owners"
    fi

    oscap-im --profile "${scap_profile}" "${scap_tailoring[@]}" \
        --results-arf /tmp/tect-scap-arf.xml "${SCAP_CONTENT}" || true
    [ -s /tmp/tect-scap-arf.xml ] || { echo "scap-remediation: the scan wrote no report"; exit 1; }

    dnf -y remove openscap-utils scap-security-guide openscap-engine-sce setools-console
    dnf -y clean all
    rm -f /tmp/tect-tailoring.xml /tmp/tect-scap-arf.xml
fi
