# Switch Node version via nvm in Bash
nvm_use_node() {
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm use "$1"
}

nvm_use_node "$@"
unset -f nvm_use_node
