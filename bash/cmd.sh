#!/usr/bin/env bash
[ -n "$BASH_VERSION" ] || return 0

# Current script path
current_script_path="${BASH_SOURCE[0]}"

##############################################################################################
# CMD_ORDER defines the display sequence of menu items.
# Items in this list appear first; others follow alphabetically at the bottom.
CMD_ORDER=(
	"_edit"
	"edit-nginx"
	"activate"
	"nvm-use-node"
	"sdk-use-java"
	"is-merged"
	"check-encode"
	"convert-encode-to-utf8"
	"pdf-translator"
)
##############################################################################################

cmd() {
    command -v fzf >/dev/null 2>&1 || { echo "fzf가 없습니다: brew install fzf"; return 1; }

    # Set script directory relative to this script
    local cmd_dir="${current_script_path%/*}/commands"
    [ -d "$cmd_dir" ] || { echo "명령어 디렉토리를 찾을 수 없습니다: $cmd_dir"; return 1; }

    # If an argument is provided, check if it matches a command name
    if [[ -n "$1" && "$1" != */* && -f "$cmd_dir/$1.sh" ]]; then
        local target_cmd="$cmd_dir/$1.sh"
        shift
        source "$target_cmd" "$@"
        return $?
    fi

    # 1. Collect all script files and their descriptions
    declare -A cmd_files
    declare -A cmd_descs
    local files=()

    for f in "$cmd_dir"/*.sh; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .sh)
        local desc=$(grep -m 1 "^# " "$f" | sed 's/^# //')
        [ -z "$desc" ] && desc="No description"
        
        cmd_files["$name"]="$f"
        cmd_descs["$name"]="$desc"
        files+=("$name")
    done

    # 2. Build ordered list
    local final_list=()
    local ordered_names=()
    local remaining_names=()
    declare -A seen_names

    # Priority items from CMD_ORDER (exact match only)
    for ordered_name in "${CMD_ORDER[@]}"; do
        if [[ -n "${cmd_files[$ordered_name]-}" ]]; then
            ordered_names+=("$ordered_name")
            seen_names["$ordered_name"]=1
        fi
    done

    # Remaining items sorted alphabetically
    for name in "${files[@]}"; do
        if [[ -z "${seen_names[$name]-}" ]]; then
            remaining_names+=("$name")
        fi
    done

    # Sort remaining names
    IFS=$'\n' sorted_remaining=($(sort <<<"${remaining_names[*]}"))
    unset IFS

    for name in "${ordered_names[@]}" "${sorted_remaining[@]}"; do
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
