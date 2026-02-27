# 깃 브랜치 스위칭
cmd_git_check() {
    if ! (( $+commands[gum] )); then
        echo "❌ `Gum` is not installed."
        return 1
    fi

    git branch | cut -c 3- | gum filter | xargs git switch
}

cmd_git_check "$@"
unfunction cmd_git_check 2>/dev/null
