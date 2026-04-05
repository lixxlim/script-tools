_activate_bash_func() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed. Please install fzf to use this function."
        return 1
    fi

    local VENV_LIST_FILE="${TMPDIR:-/tmp}/venv-list"
    local RESCAN_LABEL="현재 폴더 기준으로 스크립트 다시 검색하기"

    scan_venv_bash() {
        find "$PWD" -type f \
            \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
            2>/dev/null > "$VENV_LIST_FILE"
    }

    while true; do
        if [ ! -f "$VENV_LIST_FILE" ] || [ ! -s "$VENV_LIST_FILE" ]; then
            scan_venv_bash
        fi

        if [ ! -s "$VENV_LIST_FILE" ]; then
            echo "No activate files found in current directory. (.venv/venv/env paths only)"
        fi

        local options
        options=$(cat "$VENV_LIST_FILE" 2>/dev/null)
        local selected
        selected="$(
            { [ -n "$options" ] && echo "$options"; echo "$RESCAN_LABEL"; } | fzf \
                --prompt='activate > ' \
                --height=40% \
                --layout=reverse \
                --border \
                --cycle
        )" || return 0

        if [ -z "$selected" ]; then
            echo "Cancelled."
            return 0
        fi

        if [ "$selected" = "$RESCAN_LABEL" ]; then
            scan_venv_bash
            continue
        fi

        if [ ! -f "$selected" ]; then
            echo "❌ 해당 파일이 존재하지 않습니다(삭제되었을 수 있습니다): $selected"
            echo "다른 항목을 선택하거나 재검색을 진행해 주세요."
            sleep 1
            continue
        fi

        if [ -L "$selected" ]; then
            echo "Refusing symlink activate file for safety: $selected"
            return 1
        fi

        local current_uid="$(id -u)"
        local file_uid
        file_uid="$(
            stat -c '%u' "$selected" 2>/dev/null || stat -f '%u' "$selected" 2>/dev/null
        )"
        if [ -z "$file_uid" ] || [ "$file_uid" != "$current_uid" ]; then
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
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Cancelled."
            return 0
        fi

        . "$selected"
        break
    done
}

_activate_bash_func "$@"
unset -f _activate_bash_func
unset -f scan_venv_bash
