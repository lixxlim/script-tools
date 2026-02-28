# sdk로 자바 버전 변경
sdk_use_java() {
    emulate -L zsh
    setopt pipefail

    if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi

    if ! command -v sdk >/dev/null 2>&1; then
        print -r -- "sdk 명령을 찾지 못했습니다. SDKMAN 초기화/설치 상태를 확인하세요."
        return 1
    fi

    local cand_dir="$HOME/.sdkman/candidates/java"
    local -a versions
    if [[ -d "$cand_dir" ]]; then
        versions=("${(@f)$(ls -1 "$cand_dir" 2>/dev/null | grep -v '^current$' | sort -Vr)}")
    fi

    if (( ${#versions} == 0 )); then
        versions=(
            "${(@f)$(sdk list java 2>/dev/null | awk '
            /installed/ {
                for (i=1;i<=NF;i++) if ($i ~ /^[0-9]/ && $i ~ /-/) { print $i; break }
            }' | sort -uVr)}"
        )
    fi

    if (( ${#versions} == 0 )); then
        print -r -- "설치된 Java 후보를 찾지 못했습니다."
        return 1
    fi

    local current=""
    current="$(sdk current java 2>/dev/null | awk '{print $NF}')" || true
    [[ "$current" == "use" || "$current" == "java" || "$current" == "in" || "$current" == "use)" ]] && current=""

    local selected=""
    if command -v gum >/dev/null 2>&1; then
        if [[ -n "$current" ]]; then
            selected="$(printf '%s\n' "${versions[@]}" | gum choose --height 15 --header "Select Java (SDKMAN)" --selected "$current")" || return 0
        else
            selected="$(printf '%s\n' "${versions[@]}" | gum choose --height 15 --header "Select Java (SDKMAN)")" || return 0
        fi
    elif command -v fzf >/dev/null 2>&1; then
        selected="$(printf '%s\n' "${versions[@]}" | fzf --height=40% --reverse --prompt='Java> ')" || return 0
    else
        print -r -- "gum 또는 fzf가 필요합니다."
        return 1
    fi

    [[ -z "$selected" ]] && return 0

    sdk default java "$selected" || return 1
    printf "\n$(java --version)\n"
}

sdk_use_java "$@"
unfunction sdk_use_java 2>/dev/null
