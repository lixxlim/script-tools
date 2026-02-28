# Check file encoding in current directory
check_encode() {
    if ! command -v nkf >/dev/null 2>&1; then
        echo "nkf is not installed. Please install nkf to use this function."
        return 1
    fi

    local file encoding
    for file in *; do
        if [[ -f "$file" ]]; then
            encoding=$(nkf -g "$file")
            echo "$file: $encoding"
        fi
    done
}

check_encode "$@"
unset -f check_encode
