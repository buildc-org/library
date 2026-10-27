if [ -z "${CONFORMS:-}" ] || [ -z "${SCAP_CONTENT:-}" ]; then
    echo "scap-remediation: no conforms, nothing to remediate"
else
    scap_added=()
    for scap_pkg in openscap-utils scap-security-guide openscap-engine-sce setools-console; do
        rpm -q "${scap_pkg}" > /dev/null 2>&1 || scap_added+=("${scap_pkg}")
    done
    if [ "${#scap_added[@]}" -gt 0 ]; then
        dnf -y install "${scap_added[@]}"
    fi

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
        echo "scap-remediation: $((${#scap_unselect[@]} / 2)) rules left to their owners"
    fi

    # A failing rule makes oscap-im exit non-zero, so the hook checks the report file instead of the exit status.
    oscap-im --profile "${scap_profile}" "${scap_tailoring[@]}" \
        --results-arf /tmp/tect-scap-arf.xml "${SCAP_CONTENT}" || true
    [ -s /tmp/tect-scap-arf.xml ] || {
        echo "scap-remediation: the scan wrote no report"
        exit 1
    }

    scap_evaluated="$(grep -o '<result>[a-z]*</result>' /tmp/tect-scap-arf.xml \
        | grep -cv 'notselected' || true)"
    echo "scap-remediation: ${scap_evaluated} rules evaluated for ${scap_profile}"
    grep -o '<result>[a-z]*</result>' /tmp/tect-scap-arf.xml | sort | uniq -c
    if [ "${scap_evaluated}" -eq 0 ]; then
        echo "scap-remediation: ${scap_profile} selected no rule, so nothing was remediated"
        exit 1
    fi

    # rpm -qa still exits 0 on a corrupt rpm database and prints the corruption on stderr, so this hook reads stderr.
    scap_rpmdb="$(rpm -qa 2>&1 > /dev/null)"
    if [ -n "${scap_rpmdb}" ]; then
        echo "scap-remediation: the rpm database is unreadable after remediation"
        echo "${scap_rpmdb}"
        exit 1
    fi

    if [ "${#scap_added[@]}" -gt 0 ]; then
        dnf -y remove "${scap_added[@]}"
    fi
    dnf -y clean all
    rm -f /tmp/tect-tailoring.xml /tmp/tect-scap-arf.xml
fi
