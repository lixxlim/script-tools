# Check git status in current directory
git_check() {
    git status
}

git_check "$@"
unfunction git_check 2>/dev/null
