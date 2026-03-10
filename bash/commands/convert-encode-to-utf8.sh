# Convert file encoding to UTF-8 in Bash
convert_encode_to_utf8() {
    if ! command -v nkf >/dev/null 2>&1; then
        echo "nkf is not installed. Please install nkf to use this function."
        return 1
    fi

    local file encode_before encode_after
    for file in *; do
        [ -f "$file" ] || continue

        encode_before=$(nkf -g "$file")
        nkf -w --overwrite "$file"
        encode_after=$(nkf -g "$file")

        if [ "$encode_before" != "$encode_after" ]; then
            echo "[ $file ] $encode_before -> $encode_after"
        fi
    done
}

convert_encode_to_utf8 "$@"
unset -f convert_encode_to_utf8
