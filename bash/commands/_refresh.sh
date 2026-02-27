# Reload the cmd.sh script
cmd__refresh() {
    local command_dir="${BASH_SOURCE[0]%/*}"
    local cmd_script="${command_dir%/*}/cmd.sh"
    source "$cmd_script"
}

cmd__refresh "$@"
unset -f cmd__refresh
