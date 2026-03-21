# Git log graph with interactive branch selection (Local by default, Ctrl-a for all)
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
    branch=$(git branch --format='%(refname:short)' | \
        fzf --header "ctrl-a: all branches, ctrl-l: local branches" \
            --bind "ctrl-a:reload(git branch --all --format='%(refname:short)' | sort -u)" \
            --bind "ctrl-l:reload(git branch --format='%(refname:short)')" \
            --preview 'git log --graph --oneline --decorate --color=always {} | head -100') || return

    git log --graph --oneline --decorate "$branch"
}

git_graph "$@"
unfunction git_graph 2>/dev/null
