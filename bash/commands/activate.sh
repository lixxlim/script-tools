# Activate context in Bash
activate() {
    echo "Activating context: $1"
}

activate "$@"
unset -f activate
