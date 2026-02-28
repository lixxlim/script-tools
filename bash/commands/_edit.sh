# Edit the cmd.sh script
_edit() {
    local command_dir="${BASH_SOURCE[0]%/*}"
    local cmd_script="${command_dir%/*}/cmd.sh"
    vi "$cmd_script" && source "$cmd_script"
}

_edit "$@"
unset -f _edit
