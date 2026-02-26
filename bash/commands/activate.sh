# Description: Activate Python venv in current directory
eval "$(find . -maxdepth 2 -type f -name "activate" -exec echo "source {}" \;)"
