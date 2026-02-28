# Print OpenRouter key limits
print_openrouter_key_limits() {
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        echo "OPENROUTER_API_KEY is not set."
        return 1
    fi
    curl -fsSL "https://openrouter.ai/api/v1/auth/key" \
        -H "Authorization: Bearer ${OPENROUTER_API_KEY}"
}

print_openrouter_key_limits "$@"
unfunction print_openrouter_key_limits 2>/dev/null
