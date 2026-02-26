# 깃 브랜치 스위칭
if ! (( $+commands[gum] )); then
  echo "❌ `Gum` is not installed."
  return 1
fi

git branch | cut -c 3- | gum filter | xargs git switch
