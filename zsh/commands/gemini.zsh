# 한 줄 프롬프트를 받아 gemini -p 실행
gemini_exec() {
    emulate -L zsh
    setopt pipefail

    if ! command -v gemini >/dev/null 2>&1; then
        print -u2 "gemini 명령을 찾지 못했습니다."
        return 1
    fi

    local prompt_text=""
    local gum_width="${COLUMNS:-}"

    if (( $# > 0 )); then
        prompt_text="$*"
    elif command -v gum >/dev/null 2>&1; then
        if [[ -z "$gum_width" || "$gum_width" != <-> || "$gum_width" -le 0 ]]; then
            gum_width="$(tput cols 2>/dev/null || print -n -- '80')"
        fi
        if [[ -z "$gum_width" || "$gum_width" != <-> || "$gum_width" -le 0 ]]; then
            gum_width="80"
        fi

        if ! prompt_text="$(
            gum input \
                --prompt "Gemini> " \
                --placeholder "Gemini에 전달할 한 줄 프롬프트를 입력하세요." \
                --width "$gum_width"
        )"; then
            local gum_status=$?
            if (( gum_status == 130 )); then
                return $gum_status
            fi
            print -u2 -- "gum 입력이 실패하여 기본 한 줄 입력 모드로 전환합니다."
            print -n -- "Gemini> "
            IFS= read -r prompt_text || return $?
        fi
    else
        print -r -- "gum이 없어 기본 한 줄 입력 모드로 전환합니다."
        print -n -- "Gemini> "
        IFS= read -r prompt_text || return $?
    fi

    if [[ -z "${prompt_text//[[:space:]]/}" ]]; then
        print -u2 "입력 내용이 비어 있어 실행하지 않았습니다."
        return 1
    fi

    if command -v gum >/dev/null 2>&1; then
        gum spin --show-output --title "Gemini 응답을 기다리는 중..." -- gemini -p "$prompt_text"
    else
        gemini -p "$prompt_text"
    fi
}

gemini_exec "$@"
unfunction gemini_exec 2>/dev/null
