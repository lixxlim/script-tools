# ollama 모델을 fzf로 선택해 클로드코드 실행
claude_with_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        echo "ollama 명령을 찾지 못했습니다." >&2
        return 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf가 필요합니다. (예: brew install fzf)" >&2
        return 1
    fi

    local model
    model="$(
        ollama list | awk 'NR > 1 {print $1}' | fzf \
            --prompt="ollama model > " \
            --layout=reverse \
            --cycle \
            --border \
            --header="ENTER 선택 / ESC 취소"
    )" || return 130

    if [[ -z "$model" ]]; then
        echo "모델 선택이 취소되었습니다." >&2
        return 130
    fi

    local context
    context="$(
        ollama show "$model" 2>/dev/null | awk '/context length/ {print $3; exit}'
    )"
    if [[ -z "$context" || ! "$context" =~ ^[0-9]+$ ]]; then
        context="$(
            ollama ps 2>/dev/null | awk -v m="$model" 'NR == 1 { n = index($0, "CONTEXT") } n > 0 && $1 == m { v = substr($0, n); gsub(/^[^0-9]+/, "", v); print v + 0; exit }'
        )"
    fi

    if [[ -n "$context" && "$context" =~ ^[0-9]+$ ]]; then
        CLAUDE_CODE_MAX_CONTEXT_TOKENS="$context" ollama launch claude --model "$model"
    else
        ollama launch claude --model "$model"
    fi
}

claude_with_ollama "$@"
unset -f claude_with_ollama
