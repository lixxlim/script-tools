#!/usr/bin/env zsh
# 오픈라우터로 클로드코드 실행

# 제외 리스트 (글로벌 상수)
typeset -ga OPENROUTER_EXCLUDE_PATTERNS=(
  #"cognitivecomputations/dolphin-mistral-24b-venice-edition:free"
  #"google/gemma*"
  #"deepseek/deepseek-r1-0528:free"
  #"liquid/lfm*"
  #"nousresearch/hermes-3-llama-3.1-405b:free"
  #"nvidia/nemotron*"
  #"stepfun/step-3.5-flash:free"
  #"meta-llama/llama-3.2-3b-instruct:free"
  #"qwen/qwen3-4b:free"
  #"openai/gpt-oss-*"
  #"meta-llama/llama-3.3-70b-*"
)

# 모델 메모 (글로벌 상수)
typeset -gA OPENROUTER_MODEL_NOTES=(
  "arcee-ai/trinity-large-preview:free" "오버리밋가능"
  "arcee-ai/trinity-mini:free" "오버리밋가능"
  "z-ai/glm-4.5-air:free" "오버리밋가능"
  "upstage/solar-pro-3:free" "오버리밋가능"
)

# 모델을 받아서 클로드코드 실행
runner_claude_code_with_openrouter() {
    emulate -L zsh
    setopt pipefail

    local model="$1"
    shift
    local -a claude_options=("$@")
    local -a claude_cmd

    if [[ -z "$model" ]]; then
        print -u2 "사용법: runner_claude_code_with_openrouter <model-id>"
        return 1
    fi

    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        print -u2 "OPENROUTER_API_KEY 환경변수가 필요합니다."
        return 1
    fi

    claude_cmd=(claude --model "$model")
    if (( ${#claude_options[@]} > 0 )); then
      claude_cmd+=("${claude_options[@]}")
    fi

    ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
    ANTHROPIC_AUTH_TOKEN="${OPENROUTER_API_KEY}" \
    ANTHROPIC_API_KEY="" \
    "${claude_cmd[@]}"
}

# 프리모델 리스트 추출
get_openrouter_free_models() {
  emulate -L zsh
  setopt pipefail

  if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    print -u2 "OPENROUTER_API_KEY 환경변수가 필요합니다."
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    print -u2 "jq가 필요합니다. (예: brew install jq)"
    return 1
  fi

  curl -fsSL "https://openrouter.ai/api/v1/models" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "Accept: application/json" \
  | jq -r '.data[] | select((.id // "") | endswith(":free")) | .id' \
  | LC_ALL=C sort -u
}

# 클로드 옵션 선택(다중선택) 후 인자 리스트 출력
select_claude_code_options() {
  emulate -L zsh
  setopt pipefail

  local selected option
  local -a args

  selected="$(
    print -rl -- \
      "--permission-mode acceptEdits" \
      "--dangerously-skip-permissions" \
      "--worktree" | fzf \
      --multi \
      --layout=reverse \
      --border \
      --prompt="Claude option > " \
      --header="SPACE 토글 · ENTER 선택/다음 · ESC 취소" \
      --bind='space:toggle' \
      --bind='enter:accept' \
      --bind='esc:abort'
  )" || return 130

  [[ -z "$selected" ]] && return 0

  for option in "${(@f)selected}"; do
    option="${option//$'\r'/}"
    case "$option" in
      "--permission-mode acceptEdits")
        args+=(--permission-mode acceptEdits)
        ;;
      "--dangerously-skip-permissions")
        args+=(--dangerously-skip-permissions)
        ;;
      "--worktree")
        args+=(--worktree)
        ;;
    esac
  done

  print -rl -- "${args[@]}"
}

# 모델선택창 표시 후 선택된 모델로 러너 실행
run_claude_code_with_openrouter() {
  emulate -L zsh
  setopt pipefail

  local selected model pat skip memo
  local -a all_models visible_models claude_options

  if ! typeset -f get_openrouter_free_models >/dev/null 2>&1; then
    print -u2 "get_openrouter_free_models 함수가 정의되어 있지 않습니다."
    return 1
  fi

  if ! typeset -f runner_claude_code_with_openrouter >/dev/null 2>&1; then
    print -u2 "runner_claude_code_with_openrouter 함수가 정의되어 있지 않습니다."
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 "fzf가 필요합니다. (예: brew install fzf)"
    return 1
  fi

  all_models=("${(@f)$(get_openrouter_free_models)}")

  if (( ${#all_models[@]} == 0 )); then
    print -u2 "OpenRouter free 모델 목록이 비어 있습니다."
    return 1
  fi

  visible_models=()
  for model in "${all_models[@]}"; do
    model="${model//$'\r'/}"

    skip=0
    for pat in "${OPENROUTER_EXCLUDE_PATTERNS[@]}"; do
      pat="${pat//$'\r'/}"
      if [[ "$model" == ${~pat} ]]; then
        skip=1
        break
      fi
    done

    (( skip )) && continue

    memo="${OPENROUTER_MODEL_NOTES[$model]:-}"
    memo="${memo//$'\r'/}"
    memo="${memo//$'\t'/ }"

    if [[ -n "$memo" ]]; then
      visible_models+=("$model | $memo")
    else
      visible_models+=("$model | ")
    fi
  done

  # 모델 직접 입력 추가 (항상 맨 아래 표시)
  visible_models+=("manual | 모델 직접 입력")

  if (( ${#visible_models[@]} == 0 )); then
    print -u2 "제외 리스트 적용 후 선택 가능한 모델이 없습니다."
    return 1
  fi

  selected="$(
    print -rl -- "${visible_models[@]}" | fzf \
      --delimiter=' \| ' \
      --with-nth=1,2 \
      --prompt="OpenRouter free model > " \
      --layout=reverse \
      --cycle \
      --border \
      --header="ENTER 선택 / ESC 취소"
  )" || return 130

  if [[ -z "$selected" ]]; then
    print -u2 "모델 선택이 취소되었습니다."
    return 130
  fi

  model="${selected%% | *}"

  if [[ "$model" == "manual" ]]; then
    print -u2 -n "모델명을 직접 입력하세요 (기본값: openrouter/free): "
    read -r model
    if [[ -z "$model" ]]; then
      model="openrouter/free"
      print -u2 "입력이 없어 기본값($model)으로 진행합니다."
    fi
  fi

  if [[ -z "$model" ]]; then
    print -u2 "선택된 모델을 파싱하지 못했습니다."
    return 1
  fi

  claude_options=("${(@f)$(select_claude_code_options)}") || return $?

  runner_claude_code_with_openrouter "$model" "${claude_options[@]}"
}

claude_code_with_openrouter() {
  emulate -L zsh
  setopt pipefail

  local action="${1:-run}"

  case "$action" in
    run)
      (( $# > 0 )) && shift
      run_claude_code_with_openrouter "$@"
      ;;
    list)
      (( $# > 0 )) && shift
      get_openrouter_free_models "$@"
      ;;
    -h|--help|help)
      cat <<'EOF'
사용법:
  run_claude_code_with_openrouter.zsh            # fzf로 모델 선택 후 실행
  run_claude_code_with_openrouter.zsh run        # 위와 동일
  run_claude_code_with_openrouter.zsh list       # free 모델 목록 출력
  run_claude_code_with_openrouter.zsh <model-id> # 특정 모델로 바로 실행
EOF
      ;;
    *)
      runner_claude_code_with_openrouter "$action"
      ;;
  esac
}

claude_code_with_openrouter "$@"

unfunction runner_claude_code_with_openrouter 2>/dev/null
unfunction get_openrouter_free_models 2>/dev/null
unfunction select_claude_code_options 2>/dev/null
unfunction run_claude_code_with_openrouter 2>/dev/null
unfunction claude_code_with_openrouter 2>/dev/null
unset OPENROUTER_EXCLUDE_PATTERNS OPENROUTER_MODEL_NOTES
