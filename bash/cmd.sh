#!/usr/bin/env bash
[ -n "$BASH_VERSION" ] || return 0

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
	vi "${SCRIPT_TOOLS_PATH}/bash/cmd.sh"
}

cmd__refresh() {
	source "${SCRIPT_TOOLS_PATH}/bash/cmd.sh"
}

cmd_activate() {
	eval "$(find . -type f -name "activate" -exec echo "source {}" \;)"
}

##############################################################################################

cmd() {
	command -v fzf >/dev/null 2>&1 || { echo "fzf가 없습니다: brew install fzf"; return 1; }
	
	local line name fn
	line=$(
		{
			for n in "${CMD_ORDER[@]}"; do
				printf "%s | %s\n" "$n" "${CMD_DESC[$n]:--}"
			done
		} | fzf \
			--delimiter=" | " \
			--with-nth=1,2 \
			--prompt='cmd > ' \
			--height=100% \
			--layout=reverse \
			--border \
			--cycle \
			--preview 'echo {2}' \
			--preview-window=down:3:wrap
	) || return $?
	
	[[ -z "$line" ]] && return 0
	name="${line%% | *}"
	fn="cmd_${name}"
	typeset -f "$fn" >/dev/null || { echo "함수를 찾을 수 없습니다: $fn"; return 1; }
	"$fn"
}
