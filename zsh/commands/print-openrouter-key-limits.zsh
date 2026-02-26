# Description: 오픈라우터 토큰 잔량 확인

emulate -L zsh
setopt pipefail

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    print -u2 "OPENROUTER_API_KEY 환경변수가 필요합니다."
    return 1
fi

if ! command -v curl >/dev/null 2>&1; then
    print -u2 "curl이 필요합니다."
    return 1
fi

if ! command -v jq >/dev/null 2>&1; then
    print -u2 "jq가 필요합니다. (예: brew install jq)"
    return 1
fi

local json
json="$(
    curl -fsSL "https://openrouter.ai/api/v1/key" \
      -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
      -H "Accept: application/json"
)" || {
    print -u2 "OpenRouter /api/v1/key 조회 실패"
    return 1
}

print -r -- "$json" | jq -r '
.data as $d |
"OpenRouter Key Status",
"  label:               \($d.label // "-")",
"  is_free_tier:        \($d.is_free_tier // "-")",
"  is_management_key:   \($d.is_management_key // "-")",
"  limit:               \($d.limit // "-")",
"  limit_remaining:     \($d.limit_remaining // "-")",
"  limit_reset:         \($d.limit_reset // "-")",
"  usage:               \($d.usage // "-")",
"  usage_daily:         \($d.usage_daily // "-")",
"  usage_weekly:        \($d.usage_weekly // "-")",
"  usage_monthly:       \($d.usage_monthly // "-")",
"  byok_usage:          \($d.byok_usage // "-")",
"  byok_usage_daily:    \($d.byok_usage_daily // "-")",
"  byok_usage_weekly:   \($d.byok_usage_weekly // "-")",
"  byok_usage_monthly:  \($d.byok_usage_monthly // "-")",
"  expires_at:          \($d.expires_at // "-")"
'

local remaining
remaining="$(print -r -- "$json" | jq -r '.data.limit_remaining // "null"')"

if [[ "$remaining" != "null" ]]; then
    if jq -ne --arg v "$remaining" '$v|tonumber <= 0' >/dev/null; then
        print -u2 "경고: 이 API 키의 limit_remaining이 0 이하입니다. (402 가능성 높음)"
        return 2
    fi
fi
