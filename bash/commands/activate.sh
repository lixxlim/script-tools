# 현재 폴더를 기준으로 파이썬 가상환경 검색
_activate_bash_func() {
    # 디버그 출력 억제
    set +x

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed. Please install fzf to use this function."
        return 1
    fi

    local VENV_LIST_FILE="${TMPDIR:-/tmp}/venv-list"
    local RESCAN_LABEL="현재 폴더 기준으로 스크립트 다시 검색하기"

    # --edit: 저장된 가상환경 리스트 파일 직접 편집
    if [ "$1" = "--edit" ]; then
        touch "$VENV_LIST_FILE"
        ${EDITOR:-vi} "$VENV_LIST_FILE"
        return 0
    fi

    # 가상환경 검색 및 중복 제거 추가 함수
    scan_venv_bash() {
        touch "$VENV_LIST_FILE"
        local found
        found=$(find "$PWD" -maxdepth 6 -type f \
            \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
            2>/dev/null)
        
        if [ -n "$found" ]; then
            # 기존 목록 유지 + 새 항목 추가 (발견 순서대로 중복 제거)
            local tmp_file="${VENV_LIST_FILE}.tmp"
            { [ -f "$VENV_LIST_FILE" ] && cat "$VENV_LIST_FILE"; echo "$found"; } | grep -v '^$' | awk '!x[$0]++' > "$tmp_file" && command mv "$tmp_file" "$VENV_LIST_FILE"
        fi
    }

    while true; do
        # 목록이 없으면 자동 검색
        if [ ! -f "$VENV_LIST_FILE" ] || [ ! -s "$VENV_LIST_FILE" ]; then
            scan_venv_bash
        fi

        local v_items v_selected
        v_items=$(cat "$VENV_LIST_FILE" 2>/dev/null)
        
        v_selected="$(
            { [ -n "$v_items" ] && echo "$v_items"; echo "$RESCAN_LABEL"; } | fzf \
                --prompt='activate > ' \
                --height=40% \
                --layout=reverse \
                --border \
                --cycle
        )" || return 0

        if [ -z "$v_selected" ]; then
            echo "Cancelled."
            return 0
        fi

        if [ "$v_selected" = "$RESCAN_LABEL" ]; then
            scan_venv_bash
            continue
        fi

        # 선택된 파일 유효성 검증
        if [ ! -f "$v_selected" ]; then
            echo "❌ 파일이 존재하지 않습니다: $v_selected"
            continue
        fi

        if [ -L "$v_selected" ]; then
            echo "Refusing symlink activate file for safety: $v_selected"
            return 1
        fi

        local current_uid="$(id -u)"
        local file_uid
        file_uid="$(stat -c '%u' "$v_selected" 2>/dev/null || stat -f '%u' "$v_selected" 2>/dev/null)"
        if [ -z "$file_uid" ] || [ "$file_uid" != "$current_uid" ]; then
            echo "Refusing activate file not owned by current user: $v_selected"
            return 1
        fi

        if ! grep -q "VIRTUAL_ENV" "$v_selected"; then
            echo "Not a typical Python venv activate script: $v_selected"
            return 1
        fi

        echo "Sourcing: $v_selected"
        printf "Continue? (y/N): "
        local answer
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Cancelled."
            return 0
        fi

        . "$v_selected"
        break
    done
}

_activate_bash_func "$@"
unset -f _activate_bash_func
unset -f scan_venv_bash
