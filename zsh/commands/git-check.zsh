# 깃 브랜치 스위칭
git_check() {
    if ! (( $+commands[fzf] )); then
        echo "❌ fzf가 없습니다: brew install fzf"
        return 1
    fi

    local selected_branch
    selected_branch="$(git branch | cut -c 3- | fzf --height=40% --reverse --prompt='Branch> ')" || return 0
    [[ -n "$selected_branch" ]] || return 0

    git switch "$selected_branch"
}

git_check "$@"
unfunction git_check 2>/dev/null
