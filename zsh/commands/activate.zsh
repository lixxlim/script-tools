# 현재 폴더를 기준으로 파이썬 가상환경 검색
activate() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ fzf가 없습니다: brew install fzf"
        return 1
    fi

    local activate_files
    activate_files="$(
        find "$PWD" -type f \
            \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
            2>/dev/null
    )"

    if [[ -z "$activate_files" ]]; then
        echo "❌ activate 파일을 찾을 수 없습니다. (.venv/venv/env 경로만 검색)"
        return 1
    fi

    local selected
    selected="$(
        printf "%s\n" "$activate_files" | fzf \
            --prompt='activate > ' \
            --height=40% \
            --layout=reverse \
            --border
    )" || return 0

    if [[ -n "$selected" ]]; then
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
    fi
}

activate "$@"
unfunction activate 2>/dev/null
