# Check if the current branch is merged into another branch
is-merged() {
  if ! (( $+commands[fzf] )); then
    echo "❌ fzf가 없습니다: brew install fzf"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Git 저장소가 아닙니다."
    return 1
  fi

  local current
  current=$(git branch --show-current)
  if [[ -z "$current" ]]; then
    echo "❌ 현재 브랜치를 확인할 수 없습니다 (Detached HEAD?)."
    return 1
  fi

  local target
  target=$(
    git for-each-ref --sort=-committerdate --format="%(refname:short)" refs/heads/ \
    | grep -v "^${current}$" \
    | fzf --info=hidden \
        --prompt="" \
        --height=40% --reverse \
        --preview 'git log --date=format:%Y-%m-%d --pretty=format:"%cd | %h %s" -10 {}' \
        --preview-window=down:10
  )

  [[ -z "$target" ]] && return

  if git merge-base --is-ancestor "$current" "$target"; then
    echo "✅ \`$current\` is merged into \`$target\`"
  else
    echo "❌ \`$current\` is NOT merged into \`$target\`"
  fi
}

is-merged "$@"
unfunction is-merged 2>/dev/null
