# Activate Python venv in current directory
cmd_activate() {
    eval "$(find . -maxdepth 2 -type f -name "activate" -exec echo "source {}" \;)"
}

cmd_activate "$@"
unset -f cmd_activate
