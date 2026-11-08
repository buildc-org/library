#!/bin/bash
set -euo pipefail

for path in ${PATHS:-}; do
    if [ -e "$path" ]; then
        echo "path:$path"
    fi
done

if [ -n "${PACKAGES:-}" ]; then
    case "${FAMILY:?probe-image: FAMILY is unset}" in
        debian | ubuntu) apt-get update -qq ;;
    esac
fi

# A base may claim a capability its package database carries and its image does not install yet.
for package in ${PACKAGES:-}; do
    version=""
    case "${FAMILY:?probe-image: FAMILY is unset}" in
        fedora | rhel)
            version="$(rpm -q --qf '%{VERSION}' -- "$package" 2> /dev/null)" || version=""
            if [ -z "$version" ]; then
                if command -v dnf5 > /dev/null; then
                    version="$(dnf5 -q repoquery --latest-limit 1 --qf '%{version}' -- "$package" 2> /dev/null | sed -n '1p')"
                else
                    version="$(dnf -q repoquery --latest-limit 1 --qf '%{version}' -- "$package" 2> /dev/null | sed -n '1p')"
                fi
            fi
            ;;
        debian | ubuntu)
            version="$(dpkg-query -W -f='${Version}' -- "$package" 2> /dev/null)" || version=""
            if [ -z "$version" ]; then
                version="$(apt-cache policy -- "$package" 2> /dev/null \
                    | awk '$1 == "Candidate:" { candidate = $2 } END { print candidate }')"
                case "$version" in
                    "" | "(none)") version="" ;;
                esac
            fi
            # A Debian package version carries an epoch and a revision that the upstream version does not. The probe drops both.
            version="${version#*:}"
            version="${version%-*}"
            ;;
        *)
            echo "probe-image: unknown family ${FAMILY}" >&2
            exit 1
            ;;
    esac
    echo "version:$package=$version"
done
