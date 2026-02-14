#!/usr/bin/env zsh
[ -n "$ZSH_VERSION" ] || return 0

# Get the absolute path of the current script
# This is a zsh-specific way to get the script's absolute path
# See https://stackoverflow.com/questions/27220573/how-to-get-the-current-scripts-directory-in-zsh
current_script_path="${(%):-%x}"

##############################################################################################

declare -a CMD_ORDER=(
	_edit
	_refresh
	activate
)

declare -A CMD_DESC=(
	[_edit]="Edit cmd file"
	[_refresh]="Reload cmd file"
	[activate]="activate python venv"
)

##############################################################################################

cmd__edit() {
	# Use the dynamically determined script path
	vi "$current_script_path"
}

cmd__refresh() {
	# Use the dynamically determined script path
	source "$current_script_path"
}

cmd_activate() {
	# This should work the same in zsh
	eval "$(find . -type f -name "activate" -exec echo "source {}" \;)"
}

##############################################################################################

cmd() {
	command -v fzf >/dev/null 2>&1 || { echo "fzf가 없습니다: brew install fzf"; return 1; }
	
	local line name fn
	line=$(
		{
			for n in "${CMD_ORDER[@]}"; do
				printf "%s	%s
" "$n" "${CMD_DESC[$n]:--}"
			done
		} | fzf 
			--delimiter=$'	' 
			--with-nth=1,2 
			--prompt='cmd > ' 
			--height=100% 
			--layout=reverse 
			--border 
			--cycle 
			--preview 'echo {2}' 
			--preview-window=down:3:wrap
	) || return $?
	
	[[ -z "$line" ]] && return 0
	name="${line%%$'	'*}"
	fn="cmd_${name}"
	# Check if function exists in zsh
	# type -w works for functions in zsh
	type -w "$fn" &> /dev/null || { echo "함수를 찾을 수 없습니다: $fn"; return 1; }
	"$fn"
}
