# Activate/Switch projects or contexts
activate() {
    if [[ -z "$1" ]]; then
        echo "Usage: activate <context-name>"
        return 1
    fi
    # (Implementation details remain the same, just prefix removed)
    echo "Activating context: $1"
}

activate "$@"
unfunction activate 2>/dev/null
