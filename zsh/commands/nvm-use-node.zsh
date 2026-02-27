# Interactively switch Node version via nvm
cmd_nvm_use_node() {
    emulate -L zsh
    setopt pipefail

    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    export NVM_DIR="$nvm_dir"

    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
    fi

    if [[ ${+functions[nvm]} -eq 0 ]]; then
        print -r -- "nvm command not found. Please ensure nvm is installed and initialized."
        return 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        print -r -- "fzf is not installed. Please install fzf to use this command."
        return 1
    fi

    local versions_dir="$NVM_DIR/versions/node"
    local -a versions
    if [[ -d "$versions_dir" ]]; then
        versions=("${(@f)$(ls -1 "$versions_dir" 2>/dev/null | grep -E '^v[0-9]+' | sort -Vr)}")
    fi

    if (( ${#versions} == 0 )); then
        versions=(
            "${(@f)$(nvm ls --no-colors 2>/dev/null \
                | sed 's/^[[:space:]>*-]*//' \
                | awk '/^v[0-9]+\.[0-9]+\.[0-9]+/ {print $1}' \
                | sort -uVr)}"
        )
    fi

    if (( ${#versions} == 0 )); then
        print -r -- "No installed Node versions found in nvm."
        return 1
    fi

    local current selected
    current="$(nvm current 2>/dev/null)" || true

    if [[ "$current" == v* ]]; then
        selected="$(
            printf '%s\n' "${versions[@]}" | fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt='Node> ' \
                --header="[nvm] Select Node Version (current: $current)"
        )" || return 0
    else
        selected="$(
            printf '%s\n' "${versions[@]}" | fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt='Node> ' \
                --header='[nvm] Select Node Version'
        )" || return 0
    fi

    [[ -z "$selected" ]] && return 0

    nvm use "$selected" || return 1
    node -v 2>/dev/null || true
}

cmd_nvm_use_node "$@"
unfunction cmd_nvm_use_node 2>/dev/null
