write_os_release() {
    local file=/usr/lib/os-release
    local link=/etc/os-release
    local version="${IMAGE_VERSION:-dev}"
    # The hook composes PRETTY_NAME because an option default cannot read the image version.
    local pretty="${OPT_PRETTY_NAME}"
    if [ -z "${pretty}" ] && [ -n "${OPT_NAME}" ]; then
        pretty="${OPT_NAME} ${version}"
    fi
    local -a fields=(
        NAME "${OPT_NAME}"
        PRETTY_NAME "${pretty}"
        DEFAULT_HOSTNAME "${OPT_DEFAULT_HOSTNAME}"
        HOME_URL "${OPT_HOME_URL}"
        DOCUMENTATION_URL "${OPT_DOCUMENTATION_URL}"
        SUPPORT_URL "${OPT_SUPPORT_URL}"
        BUG_REPORT_URL "${OPT_BUG_REPORT_URL}"
        IMAGE_VERSION "${version}"
    )
    local -A set=()
    local -a keys=()
    local at
    for ((at = 0; at < ${#fields[@]}; at += 2)); do
        if [ -n "${fields[at + 1]}" ]; then
            set[${fields[at]}]="${fields[at + 1]}"
            keys+=("${fields[at]}")
        fi
    done

    local key value line text out=""
    for key in "${keys[@]}"; do
        value="${set[$key]//\\/\\\\}"
        value="${value//\"/\\\"}"
        value="${value//\$/\\\$}"
        value="${value//\`/\\\`}"
        set[$key]="\"${value}\""
    done
    text="$(< "${file}")"
    local -A found=()
    while IFS= read -r line; do
        key="${line%%=*}"
        if [ "${key}" != "${line}" ] && [ -n "${set[$key]+x}" ]; then
            out+="${key}=${set[$key]}"$'\n'
            found[$key]=1
        else
            out+="${line}"$'\n'
        fi
    done <<< "${text}"
    for key in "${keys[@]}"; do
        if [ -z "${found[$key]+x}" ]; then
            out+="${key}=${set[$key]}"$'\n'
        fi
    done

    rm -f "${file}"
    printf '%s' "${out}" > "${file}"
    ln -sfn ../usr/lib/os-release "${link}"
}

write_os_release
