flatpak_write_list() {
    local target="$1"
    shift
    [ "$#" -gt 0 ] || return 0
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$@" > "$target"
}
