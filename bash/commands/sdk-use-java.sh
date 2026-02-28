# Switch Java version via SDKMAN! in Bash
sdk_use_java() {
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk use java "$1"
}

sdk_use_java "$@"
unset -f sdk_use_java
