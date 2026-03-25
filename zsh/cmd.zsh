#!/usr/bin/env zsh
[ -n "$ZSH_VERSION" ] || return 0

# 현재 스크립트 위치
current_script_path="${(%):-%x}"

#########################################################################################
# 커맨드 오더 정렬 (없을 경우 이름순 정렬)
typeset -ga CMD_ORDER
CMD_ORDER=(
    "run-claude-code-with-openrouter"
    "print-openrouter-key-limits"
    "jules_commander"
    "sdk-use-java"
    "nvm-use-node"
    "git-check"
    "git-graph"
    "gh-workflow-run"
    "is-merged"
    "activate"
    "idea"
    "codex"
    "gemini"
    "spring-init"
    "pdf-translator"
    "transcribe"
    "check-encode"
    "convert-encode-to-utf8"
)
#########################################################################################

cmd() {
    command -v fzf >/dev/null 2>&1 || { echo "fzf가 없습니다: brew install fzf"; return 1; }

    # Set script directory relative to this script
    local cmd_dir="${current_script_path:h}/commands"
    [ -d "$cmd_dir" ] || { echo "명령어 디렉토리를 찾을 수 없습니다: $cmd_dir"; return 1; }

    # If an argument is provided, check if it matches a command name
    if [[ -n "$1" && "$1" != */* && -f "$cmd_dir/$1.zsh" ]]; then
        local target_cmd="$cmd_dir/$1.zsh"
        shift
        source "$target_cmd" "$@"
        return $?
    fi

    # 1. Collect all script files and their descriptions
    typeset -A cmd_files
    typeset -A cmd_descs
    local files=()

    for f in "$cmd_dir"/*.zsh; do
        [ -f "$f" ] || continue
        local name="${f:t:r}"
        # Extract description from first '# ' comment line
        local desc=$(grep -m 1 "^# " "$f" | sed 's/^# //')
        [ -z "$desc" ] && desc="No description"
        
        cmd_files[$name]="$f"
        cmd_descs[$name]="$desc"
        files+=("$name")
    done

    # 2. Build ordered list
    local final_list=()
    local ordered_names=()
    local remaining_names=()
    typeset -A seen_names

    # Priority items from CMD_ORDER (exact match only)
    for ordered_name in "${CMD_ORDER[@]}"; do
        if [[ -n "${cmd_files[$ordered_name]-}" ]]; then
            ordered_names+=("$ordered_name")
            seen_names[$ordered_name]=1
        fi
    done

    # Remaining items sorted alphabetically
    for name in "${files[@]}"; do
        if [[ -z "${seen_names[$name]-}" ]]; then
            remaining_names+=("$name")
        fi
    done
    remaining_names=(${(o)remaining_names})

    for name in "${ordered_names[@]}" "${remaining_names[@]}"; do
        final_list+=("$name | ${cmd_descs[$name]}")
    done

    # 3. Use fzf to select command
    local line selected_name
    line=$(
        printf "%s\n" "${final_list[@]}" | fzf \
            --delimiter='\s*\|\s*' \
            --with-nth=1,2 \
            --no-sort \
            --prompt='cmd > ' \
            --height=100% \
            --layout=reverse \
            --border \
            --cycle \
            --preview 'echo {2}' \
            --preview-window=down:3:wrap
    ) || return $?

    [[ -z "$line" ]] && return 0
    selected_name="${line%% | *}"
    
    # 4. Execute the selected script via source
    local selected_path="${cmd_files[$selected_name]}"
    [[ -n "$selected_path" ]] || { echo "선택한 명령 경로를 찾을 수 없습니다: $selected_name"; return 1; }
    source "$selected_path"
}
