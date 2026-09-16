# Display function definition, source file, and command details
whatis() {
  if [[ -z "$1" ]]; then
    echo "Usage: whatis <command_or_function>"
    return 1
  fi

  whence -v "$1"

  if (( $+functions[$1] )); then
    if [[ -n "${functions_source[$1]}" ]]; then
      echo "Defined in: ${functions_source[$1]}"
    fi
    echo "--- Definition ---"
    functions "$1"
  fi
}

whatis "$@"
unfunction whatis 2>/dev/null
