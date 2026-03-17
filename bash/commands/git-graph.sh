# Git log graph with interactive branch selection
git_graph() {
    if ! command -v git >/dev/null 2>&1; then
        echo "git is not installed."
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed."
        return 1
    fi

    local branch
    branch=$(git branch --all --format='%(refname:short)' | sort -u | \
        fzf --preview 'git log --graph --oneline --decorate --color=always {} | head -100') || return

    git log --graph --oneline --decorate "$branch"
}

git_graph "$@"
unset -f git_graph
