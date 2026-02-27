# Interactively select and use an installed Java version via SDKMAN!
cmd_sdk_use_java() {
    # SDKMAN! is often a shell function, so we check for its availability.
    if ! command -v sdk >/dev/null 2>&1; then
        if [[ $(type -t sdk 2>/dev/null) != "function" ]]; then
            echo "Error: sdk command not found. Please ensure SDKMAN! is installed and initialized."
            return 1
        fi
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: fzf is not installed. Please install fzf to use this command."
        return 1
    fi

    local selection
    selection=$(sdk list java | grep -E 'installed|>>>' | awk -F '|' '{print $NF}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | fzf --header="[SDKMAN] Select Java Version" --height=15 --reverse --border)

    if [[ -n "$selection" ]]; then
        sdk use java "$selection"
    else
        echo "Cancelled."
    fi
}

cmd_sdk_use_java "$@"
unset -f cmd_sdk_use_java
