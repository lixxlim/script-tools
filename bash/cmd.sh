#!/usr/bin/env bash
[ -n "$BASH_VERSION" ] || return 0

##############################################################################################
# CMD_ORDER defines the display sequence of menu items.
# Items in this list appear first; others follow alphabetically at the bottom.
CMD_ORDER=("_edit" "_refresh" "activate")
##############################################################################################

cmd() {
    command -v fzf >/dev/null 2>&1 || { echo "fzf가 없습니다: brew install fzf"; return 1; }

    local cmd_dir="${SCRIPT_TOOLS_PATH}/bash/commands"
    [ -d "$cmd_dir" ] || { echo "명령어 디렉토리를 찾을 수 없습니다: $cmd_dir"; return 1; }

    # 1. Collect all script files and their descriptions
    declare -A cmd_files
    declare -A cmd_descs
    local files=()

    for f in "$cmd_dir"/*.sh; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .sh)
        local desc=$(grep -m 1 "^# Description:" "$f" | sed 's/^# Description: //')
        [ -z "$desc" ] && desc="No description"
        
        cmd_files["$name"]="$f"
        cmd_descs["$name"]="$desc"
        files+=("$name")
    done

    # 2. Build ordered list based on CMD_ORDER
    local final_list=()
    local seen_names=()

    # Priority items from CMD_ORDER
    for ordered_name in "${CMD_ORDER[@]}"; do
        if [[ -n "${cmd_files[$ordered_name]}" ]]; then
            final_list+=("$ordered_name | ${cmd_descs[$ordered_name]}")
            seen_names+=("$ordered_name")
        fi
    done

    # Remaining items sorted alphabetically
    local remaining=()
    for name in "${files[@]}"; do
        local is_seen=0
        for s in "${seen_names[@]}"; do
            [[ "$s" == "$name" ]] && { is_seen=1; break; }
        done
        [[ $is_seen -eq 0 ]] && remaining+=("$name")
    done

    # Sort remaining names
    IFS=$'\n' sorted_remaining=($(sort <<<"${remaining[*]}"))
    unset IFS

    for name in "${sorted_remaining[@]}"; do
        final_list+=("$name | ${cmd_descs[$name]}")
    done

    # 3. Use fzf to select command
    local line selected_name
    line=$(
        printf "%s\n" "${final_list[@]}" | fzf \
            --delimiter='\s*\|\s*' \
            --with-nth=1,2 \
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
    source "${cmd_files[$selected_name]}"
}
