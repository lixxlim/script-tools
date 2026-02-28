# 한 줄 프롬프트를 받아 codex exec 실행
codex_exec() {
    emulate -L zsh
    setopt pipefail

    if ! command -v codex >/dev/null 2>&1; then
        print -u2 "codex 명령을 찾지 못했습니다."
        return 1
    fi

    local prompt_text=""

    if (( $# > 0 )); then
        prompt_text="$*"
    elif command -v gum >/dev/null 2>&1; then
        if ! prompt_text="$(
            gum input \
                --prompt "Codex> " \
                --placeholder "Codex에 전달할 한 줄 프롬프트를 입력하세요." \
                2>/dev/null
        )"; then
            local gum_status=$?
            if (( gum_status == 130 )); then
                return $gum_status
            fi
            print -u2 -- "gum 입력이 실패하여 기본 한 줄 입력 모드로 전환합니다."
            print -n -- "Codex> "
            IFS= read -r prompt_text || return $?
        fi
    else
        print -r -- "gum이 없어 기본 한 줄 입력 모드로 전환합니다."
        print -n -- "Codex> "
        IFS= read -r prompt_text || return $?
    fi

    if [[ -z "${prompt_text//[[:space:]]/}" ]]; then
        print -u2 "입력 내용이 비어 있어 실행하지 않았습니다."
        return 1
    fi

    codex exec -- "$prompt_text"
}

codex_exec "$@"
unfunction codex_exec 2>/dev/null
