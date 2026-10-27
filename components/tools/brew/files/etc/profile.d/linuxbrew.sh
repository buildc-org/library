if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # brew shellenv puts its bin ahead of the image's own tools, so the profile drops every brew path and appends bin and sbin.
    HOMEBREW_PATHS="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -vF "${HOMEBREW_PREFIX}/" | tr '\n' ':')"
    PATH="${PATH%:}:${HOMEBREW_PATHS}"
    export PATH
    unset HOMEBREW_PATHS
fi
