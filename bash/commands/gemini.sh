# Run gemini -p with a single-line prompt
gemini_exec() {
    if ! command -v gemini >/dev/null 2>&1; then
        echo "gemini 명령을 찾지 못했습니다." >&2
        return 1
    fi

    local prompt_text=""
    local gum_width="${COLUMNS:-}"

    if [[ $# -gt 0 ]]; then
        prompt_text="$*"
    elif command -v gum >/dev/null 2>&1; then
        if [[ -z "$gum_width" || ! "$gum_width" =~ ^[0-9]+$ || "$gum_width" -le 0 ]]; then
            gum_width="$(tput cols 2>/dev/null || printf '80')"
        fi
        if [[ -z "$gum_width" || ! "$gum_width" =~ ^[0-9]+$ || "$gum_width" -le 0 ]]; then
            gum_width="80"
        fi

        if ! prompt_text="$(
            gum input \
                --prompt "Gemini> " \
                --placeholder "Gemini에 전달할 한 줄 프롬프트를 입력하세요." \
                --width "$gum_width"
        )"; then
            local gum_status=$?
            if [[ $gum_status -eq 130 ]]; then
                return $gum_status
            fi
            echo "gum 입력이 실패하여 기본 한 줄 입력 모드로 전환합니다." >&2
            printf "Gemini> "
            IFS= read -r prompt_text || return $?
        fi
    else
        echo "gum이 없어 기본 한 줄 입력 모드로 전환합니다."
        printf "Gemini> "
        IFS= read -r prompt_text || return $?
    fi

    if [[ -z "${prompt_text//[[:space:]]/}" ]]; then
        echo "입력 내용이 비어 있어 실행하지 않았습니다." >&2
        return 1
    fi

    if command -v gum >/dev/null 2>&1; then
        gum spin --show-output --title "Gemini 응답을 기다리는 중..." -- gemini -p "$prompt_text"
    else
        gemini -p "$prompt_text"
    fi
}

gemini_exec "$@"
unset -f gemini_exec
