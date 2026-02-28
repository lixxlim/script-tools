# 현재 폴더에서 IntelliJ IDEA 열기
open_idea() {
    if [[ "$OSTYPE" != darwin* ]]; then
        echo "Error: This command is only supported on macOS."
        return 1
    fi

    if ! open -Ra "IntelliJ IDEA" >/dev/null 2>&1; then
        echo "Error: IntelliJ IDEA is not installed or could not be found in Applications."
        return 1
    fi

    open -a "IntelliJ IDEA" .
}

open_idea "$@"
unfunction open_idea 2>/dev/null
