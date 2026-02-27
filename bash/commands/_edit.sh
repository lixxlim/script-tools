# Edit the cmd.sh script
cmd__edit() {
    local command_dir="${BASH_SOURCE[0]%/*}"
    local cmd_script="${command_dir%/*}/cmd.sh"
    vi "$cmd_script"
}

cmd__edit "$@"
unset -f cmd__edit
