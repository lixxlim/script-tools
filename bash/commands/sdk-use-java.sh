# Switch Java version via SDKMAN! in Bash
sdk_use_java() {
    local cand_dir current selected version
    local versions=()

    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

    if ! command -v sdk >/dev/null 2>&1; then
        echo "sdk command not found. Please ensure SDKMAN! is installed and initialized."
        return 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is not installed. Please install fzf to use this command."
        return 1
    fi

    cand_dir="$HOME/.sdkman/candidates/java"
    if [[ -d "$cand_dir" ]]; then
        while IFS= read -r version; do
            [[ -n "$version" ]] && versions+=("$version")
        done < <(ls -1 "$cand_dir" 2>/dev/null | grep -v '^current$' | sort -Vr)
    fi

    if [[ ${#versions[@]} -eq 0 ]]; then
        while IFS= read -r version; do
            [[ -n "$version" ]] && versions+=("$version")
        done < <(
            sdk list java 2>/dev/null | awk '
                /installed/ {
                    for (i=1;i<=NF;i++) if ($i ~ /^[0-9]/ && $i ~ /-/) { print $i; break }
                }' | sort -uVr
        )
    fi

    if [[ ${#versions[@]} -eq 0 ]]; then
        echo "No installed Java candidates found in SDKMAN!."
        return 1
    fi

    current="$(sdk current java 2>/dev/null | awk '{print $NF}' || true)"
    if [[ "$current" == "use" || "$current" == "java" || "$current" == "in" || "$current" == "use)" ]]; then
        current=""
    fi

    if [[ -n "$current" ]]; then
        selected="$(
            printf '%s\n' "${versions[@]}" | fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt='Java> ' \
                --header="[sdk] Select Java Candidate (current: $current)"
        )" || return 0
    else
        selected="$(
            printf '%s\n' "${versions[@]}" | fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt='Java> ' \
                --header='[sdk] Select Java Candidate'
        )" || return 0
    fi

    [[ -z "$selected" ]] && return 0

    sdk use java "$selected" || return 1
    java --version 2>/dev/null || true
}

sdk_use_java "$@"
unset -f sdk_use_java
