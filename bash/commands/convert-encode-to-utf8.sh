# Convert file encoding to UTF-8 in Bash
convert_encode_to_utf8() {
    if ! command -v nkf >/dev/null 2>&1; then
        echo "nkf is not installed. Please install nkf to use this function."
        return 1
    fi

    local file
    for file in *; do
        [ -f "$file" ] || continue
        nkf -w --overwrite "$file"
    done
}

convert_encode_to_utf8 "$@"
unset -f convert_encode_to_utf8
