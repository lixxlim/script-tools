# 일정이상 커밋이 없는 브런치를 선택하여 로컬 및 리모트에서 삭제합니다.
git_clean_branches() {
  if ! (( $+commands[fzf] )); then
    echo "❌ fzf가 없습니다: brew install fzf"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Git 저장소가 아닙니다."
    return 1
  fi

  # 보호할 브랜치 설정 (Regex 형태)
  local PROTECTED_BRANCHES="^(main|master|stg|dev|develop)$"
  local days=${1:-30}
  local now=$(date +%s)
  local threshold=$((days * 24 * 3600))
  local limit=$((now - threshold))
  local current_branch=$(git branch --show-current)

  echo "🔍 ${days}일 동안 커밋이 없는 브랜치를 찾고 있습니다... (현재 브랜치: $current_branch)"
  echo "ℹ️ 보호되는 브랜치(제외됨): main, master, stg, dev, develop"

  local branches_list=""
  local count=0

  # git for-each-ref output: unix_timestamp \t relative_date \t short_date \t ref_name \t upstream
  while IFS=$'\t' read -r unix relative date ref upstream; do
    # 1. 현재 브랜치 제외
    [[ "$ref" == "$current_branch" ]] && continue
    
    # 2. 보호된 브랜치 제외
    [[ "$ref" =~ $PROTECTED_BRANCHES ]] && continue
    
    # 3. 일정 기간 이상 된 브랜치만 포함
    if (( unix < limit )); then
      branches_list+="$relative | $date | $ref | $upstream"$'\n'
      ((count++))
    fi
  done < <(git for-each-ref --sort=-committerdate --format="%(committerdate:unix)%09%(committerdate:relative)%09%(committerdate:short)%09%(refname:short)%09%(upstream:short)" refs/heads/)

  if [[ $count -eq 0 ]]; then
    echo "✅ ${days}일 이상 된 삭제 대상 브랜치가 없습니다."
    return 0
  fi

  local selected
  selected=$(echo -n "$branches_list" | fzf -m \
    --header "Tab으로 다중 선택 가능 / Enter로 확정 (최근 커밋순 / 보호 브랜치 제외)" \
    --prompt "${days}일 이상 된 브랜치 선택 > " \
    --height=60% --reverse \
    --preview 'git log --oneline --graph --color=always -n 10 $(echo {} | awk -F " | " "{print \$3}")' \
    --preview-window=down:10)

  [[ -z "$selected" ]] && return

  echo -e "\n다음 브랜치들을 삭제합니다:"
  echo "$selected" | awk -F ' | ' '{print "  - " $3 " (" $1 ")"}'

  echo -n "정말로 삭제하시겠습니까? (y/N): "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    return 0
  fi

  while IFS=' | ' read -r relative date branch upstream; do
    echo -e "\n--- Branch: $branch ($relative) ---"
    
    # 1. Local branch 삭제
    if git branch -D "$branch"; then
      echo "✅ 로컬 브랜치 '$branch' 삭제 완료"
    else
      echo "❌ 로컬 브랜치 '$branch' 삭제 실패"
    fi

    # 2. Remote branch 삭제 (존재하는 경우)
    if [[ -n "$upstream" ]]; then
      local remote="${upstream%%/*}"
      local remote_branch="${upstream#*/}"
      echo "리모트 브랜치 삭제를 시도합니다: $remote/$remote_branch"
      
      if git ls-remote --exit-code --heads "$remote" "$remote_branch" >/dev/null 2>&1; then
        if git push "$remote" --delete "$remote_branch"; then
          echo "✅ 리모트 브랜치 '$remote/$remote_branch' 삭제 완료"
        else
          echo "❌ 리모트 브랜치 '$remote/$remote_branch' 삭제 실패"
        fi
      else
        echo "ℹ️ 리모트 브랜치 '$remote/$remote_branch'가 이미 존재하지 않거나 접근할 수 없습니다."
      fi
    fi
  done <<< "$selected"
}

git_clean_branches "$@"
unfunction git_clean_branches 2>/dev/null
