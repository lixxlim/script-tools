# Print OpenRouter key limits
print_openrouter_key_limits() {
    emulate -L zsh
    setopt pipefail

    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        print -u2 "OPENROUTER_API_KEY is not set."
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        print -u2 "curl is required."
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        print -u2 "jq is required. (e.g., brew install jq)"
        return 1
    fi

    local json
    json="$(
        curl -fsSL "https://openrouter.ai/api/v1/key" \
          -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
          -H "Accept: application/json"
    )" || {
        print -u2 "Failed to fetch OpenRouter key info from /api/v1/key"
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
            print -u2 "Warning: limit_remaining is 0 or less. (402 Payment Required likely)"
            return 2
        fi
    fi
}

print_openrouter_key_limits "$@"
unfunction print_openrouter_key_limits 2>/dev/null
