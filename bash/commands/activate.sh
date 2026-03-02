# Activate Python venv in current directory (fzf selection)
activate() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed. Please install fzf to use this function."
        return 1
    fi

    local activate_files
    activate_files="$(
        find "$PWD" -type f \
            \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
            2>/dev/null
    )"

    if [[ -z "$activate_files" ]]; then
        echo "No activate files found. (searched only .venv/venv/env paths)"
        return 1
    fi

    local selected
    selected="$(
        printf '%s\n' "$activate_files" | fzf \
            --prompt='activate > ' \
            --height=40% \
            --layout=reverse \
            --border
    )" || return 0

    if [[ -z "$selected" ]]; then
        echo "Cancelled."
        return 0
    fi

    if [[ -L "$selected" ]]; then
        echo "Refusing symlink activate file for safety: $selected"
        return 1
    fi

    if [[ ! -O "$selected" ]]; then
        echo "Refusing activate file not owned by current user: $selected"
        return 1
    fi

    if ! grep -q "VIRTUAL_ENV" "$selected"; then
        echo "Not a typical Python venv activate script: $selected"
        return 1
    fi

    echo "Sourcing this file executes shell code: $selected"
    printf "Continue? (y/N): "
    local answer
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Cancelled."
        return 0
    fi

    source "$selected"
}

activate "$@"
unset -f activate
