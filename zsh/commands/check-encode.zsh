# Check file encoding in current directory
# Check if nkf is installed
if ! command -v nkf &> /dev/null; then
    echo "nkf is not installed. Please install nkf to use this function."
else
    for file in *; do
        if [[ -f "$file" ]]; then
            encoding=$(nkf -g "$file")
            echo "$file: $encoding"
        fi
    done
fi
