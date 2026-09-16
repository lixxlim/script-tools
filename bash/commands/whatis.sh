# Display function definition, source file, and command details
whatis() {
  if [ -z "$1" ]; then
    echo "Usage: whatis <command_or_function>"
    return 1
  fi
  ( shopt -s extdebug; declare -F "$1" 2>/dev/null )
  type "$1"
}

whatis "$@"
unset -f whatis 2>/dev/null
