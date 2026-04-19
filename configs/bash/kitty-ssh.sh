# Prefer Kitty's SSH wrapper inside Kitty so split windows can follow
# remote sessions and preserve the current remote working directory.
ssh() {
    if [[ -n "${KITTY_WINDOW_ID:-}" ]] && command -v kitten &>/dev/null; then
        command kitten ssh "$@"
        return
    fi

    case "$TERM" in
        xterm-kitty|kitty)
            TERM=xterm-256color command ssh "$@"
            ;;
        *)
            command ssh "$@"
            ;;
    esac
}
