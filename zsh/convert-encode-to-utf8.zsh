function convert_encode_to_utf8() {
    # Check if nkf is installed
    if ! command -v nkf &> /dev/null; then
        echo "nkf is not installed. Please install nkf to use this function."
        return 1
    fi

    for file in *; do
        [ -f "$file" ] || continue

        encode_before=$(nkf -g "$file")
        nkf -w --overwrite "$file"
        encode_after=$(nkf -g "$file")

        if [ "$encode_before" != "$encode_after" ]; then
            echo "[ $file ] $encode_before → $encode_after"
        fi
    done
}