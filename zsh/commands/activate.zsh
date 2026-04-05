# 현재 폴더를 기준으로 파이썬 가상환경 검색
activate() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ fzf가 없습니다: brew install fzf"
        return 1
    fi

    local VENV_LIST_FILE="${TMPDIR:-/tmp}/venv-list"
    local RESCAN_LABEL="현재 폴더 기준으로 스크립트 다시 검색하기"

    scan_venv() {
        find "$PWD" -type f \
            \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
            2>/dev/null > "$VENV_LIST_FILE"
    }

    while true; do
        if [[ ! -f "$VENV_LIST_FILE" || ! -s "$VENV_LIST_FILE" ]]; then
            scan_venv
        fi

        local options
        options=$(cat "$VENV_LIST_FILE" 2>/dev/null)
        
        local selected
        selected="$(
            { [[ -n "$options" ]] && echo "$options"; echo "$RESCAN_LABEL"; } | fzf \
                --prompt='activate > ' \
                --height=40% \
                --layout=reverse \
                --border \
                --cycle
        )" || return 0

        if [[ -z "$selected" ]]; then
            echo "취소되었습니다."
            return 0
        fi

        if [[ "$selected" == "$RESCAN_LABEL" ]]; then
            scan_venv
            continue
        fi

        if [[ ! -f "$selected" ]]; then
            echo "❌ 해당 파일이 존재하지 않습니다(삭제되었을 수 있습니다): $selected"
            echo "다른 항목을 선택하거나 재검색을 진행해 주세요."
            sleep 1
            continue
        fi

        if [[ -L "$selected" ]]; then
            echo "❌ 심볼릭 링크 activate는 보안상 허용하지 않습니다: $selected"
            return 1
        fi

        if [[ ! -O "$selected" ]]; then
            echo "❌ 현재 사용자 소유가 아닌 activate 파일은 허용하지 않습니다: $selected"
            return 1
        fi

        if ! grep -q "VIRTUAL_ENV" "$selected"; then
            echo "❌ 일반적인 Python venv activate 스크립트 형태가 아닙니다: $selected"
            return 1
        fi

        echo "선택한 파일을 source 하면 쉘 코드가 실행됩니다: $selected"
        echo -n "계속할까요? (y/N): "
        local answer
        read -r answer
        if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
            echo "취소되었습니다."
            return 0
        fi

        source "$selected"
        break
    done
}

activate "$@"
unfunction activate 2>/dev/null
unfunction scan_venv 2>/dev/null
