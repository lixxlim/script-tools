# Load Custom Scripts
CUSTOM_FUNCTIONS_DIR="$HOME/works/scripts.d"
if [ -d "$CUSTOM_FUNCTIONS_DIR" ]; then
  for script_file in "$CUSTOM_FUNCTIONS_DIR"/*.sh; do
    if [ -f "$script_file" ]; then
      source "$script_file"
    fi
  done
fi

function cmd() {
    # Check if gum is installed
    if ! command -v gum &> /dev/null; then
        echo "gum is not installed. Please install gum to use this function."
        return 1
    fi

    local cmds=(
        "check-encode"
        "convert-encode-to-utf8"
    )
    local selected=$(printf "%s\n" "${cmds[@]}" | gum choose)

    if [ -z "$selected" ]; then
        return 1
    fi

    "$selected" "$@"
};