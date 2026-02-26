#!/bin/zsh
# 줄즈 커맨드

# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------
# Ordered keys for display
local labels=("List Repos" "List Sessions" "New Remote Session" "Pull Session" "Teleport")

local selected=1
local total=${#labels[@]}
local key=""

# Execute argv safely without eval.
run_command() {
    local -a cmd=("$@")
    echo "\n--------------------------------------------------"
    printf "Executing:"
    printf " %q" "${cmd[@]}"
    echo "\n--------------------------------------------------\n"
    "${cmd[@]}"
}

# Helper function: Generic Menu Selection
# Arguments: "Title" "Array of Items"
# Returns: selected item in $RESULT global variable, or empty if cancelled
select_from_menu() {
    local title="$1"
    shift
    local items=("$@")
    local sel=1
    local tot=${#items[@]}
    local k=""

    tput civis
    while true; do
        # We clear only the lines we need or just clear screen for simplicity
        clear
        echo "\n  $title\n"
        for ((j=1; j<=tot; j++)); do
            if [[ $j -eq $sel ]]; then
                echo "  $(tput rev) ${items[$j]} $(tput sgr0)"
            else
                echo "    ${items[$j]}"
            fi
        done
        echo "\n  (Press ESC to cancel)"
        
        read -s -k 1 k
        if [[ $k == $'\e' ]]; then
            # Check for arrow keys vs plain ESC
            # We read with a tiny timeout to distinguish ESC from sequence
            # zsh specific read with timeout -t
            read -s -t 0.1 -k 2 k2
            if [[ $? -eq 0 ]]; then
                # It was a sequence
                case "$k2" in
                    '[A') ((sel--)); if [[ $sel -lt 1 ]]; then sel=$tot; fi ;;
                    '[B') ((sel++)); if [[ $sel -gt $tot ]]; then sel=1; fi ;;
                esac
            else
                # It was plain ESC
                sel=-1
                break
            fi
        elif [[ $k == "" || $k == $'\n' || $k == $'\r' ]]; then
            break
        elif [[ $k == "q" ]]; then
            sel=-1
            break
        fi
    done
    tput cnorm
    
    if [[ $sel -eq -1 ]]; then
        RESULT=""
    else
        RESULT="${items[$sel]}"
    fi
}

# Main Menu Loop
tput civis
cleanup() {
    tput cnorm
    # Clear menu area (rough estimate)
    for ((i=0; i<=total+5; i++)); do tput cuu1; tput el; done
}
trap cleanup EXIT INT

while true; do
    clear
    echo "\n  Jules CLI Commander\n"

    for ((i=1; i<=total; i++)); do
        if [[ $i -eq $selected ]]; then
            echo "  $(tput rev) ${labels[$i]} $(tput sgr0)"
        else
            echo "    ${labels[$i]}"
        fi
    done
    echo "\n  (Press ESC to cancel)"

    read -s -k 1 key
    if [[ $key == $'\e' ]]; then
         read -s -t 0.1 -k 2 key2
         if [[ $? -eq 0 ]]; then
            case "$key2" in
                '[A') ((selected--)); if [[ $selected -lt 1 ]]; then selected=$total; fi ;;
                '[B') ((selected++)); if [[ $selected -gt $total ]]; then selected=1; fi ;;
            esac
         else
            # Plain ESC
            echo "\nCancelled."
            return
         fi
    elif [[ $key == "" || $key == $'\n' || $key == $'\r' ]]; then
        break
    elif [[ $key == "q" ]]; then
        echo "\nExiting..."
        return
    fi
done
tput cnorm
trap - EXIT INT

# ------------------------------------------------------------------
# Parameter Extraction & Execution Logic
# ------------------------------------------------------------------
local label="${labels[$selected]}"

echo "\nSelected: $label"

case "$label" in
    "List Repos")
        run_command jules remote list --repo
        ;;
    "List Sessions")
        run_command jules remote list --session
        ;;
    "New Remote Session")
        echo "Fetching repository list..."
        local repo_list_raw
        if ! repo_list_raw="$(jules remote list --repo)"; then
            echo "No repositories found or error fetching them."
            return 1
        fi
        local -a repo_list=("${(@f)repo_list_raw}")
        if [[ ${#repo_list[@]} -eq 0 ]]; then
            echo "No repositories found."
            return 1
        fi

        select_from_menu "Select Repository" "${repo_list[@]}"
        local chosen_repo="$RESULT"
        if [[ -z "$chosen_repo" ]]; then
            echo "Cancelled."
            return
        fi

        local task_description
        echo -n "\nEnter value for 'task_description' (Enter to skip): "
        read -r task_description

        run_command jules remote new --repo "$chosen_repo" --session "$task_description"
        ;;
    "Pull Session"|"Teleport")
        echo "Fetching session list..."
        local session_list_raw
        if ! session_list_raw="$(jules remote list --session)"; then
            echo "No sessions found."
            return 1
        fi
        local -a session_list=("${(@f)session_list_raw}")
        if [[ ${#session_list[@]} -eq 0 ]]; then
            echo "No sessions found."
            return 1
        fi

        select_from_menu "Select Session" "${session_list[@]}"
        local chosen_session_line="$RESULT"
        if [[ -z "$chosen_session_line" ]]; then
            echo "Cancelled."
            return
        fi

        local session_id="${chosen_session_line%%[[:space:]]*}"
        if [[ -z "$session_id" ]]; then
            echo "Failed to parse session ID."
            return 1
        fi

        if [[ "$label" == "Pull Session" ]]; then
            local -a pull_cmd=(jules remote pull --session "$session_id")
            local apply_choice
            echo -n "\nDo you want to apply the changes? (y/N): "
            read -r apply_choice
            if [[ "$apply_choice" == "y" || "$apply_choice" == "Y" ]]; then
                pull_cmd+=(--apply)
            fi
            run_command "${pull_cmd[@]}"
        else
            run_command jules teleport "$session_id"
        fi
        ;;
esac
