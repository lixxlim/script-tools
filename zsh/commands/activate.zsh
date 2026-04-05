# 현재 폴더를 기준으로 파이썬 가상환경 검색
activate() {
    # 쉘 옵션 로컬화 및 디버그 출력 억제
    emulate -L zsh
    unsetopt xtrace verbose 2>/dev/null

    if ! command -v fzf >/dev/null 2>&1; then
        command echo "❌ fzf가 없습니다: brew install fzf"
        return 1
    fi

    local v_list="/tmp/venv-list-${USER}"
    local v_rescan="현재 폴더 기준으로 스크립트 다시 검색하기"
    local v_do_scan=0

    # --edit: 저장된 가상환경 리스트 파일 직접 편집
    if [[ "$1" == "--edit" ]]; then
        command touch "$v_list"
        ${EDITOR:-vi} "$v_list"
        return 0
    fi

    # 목록이 없거나 비어있으면 초기 스캔 예약
    [[ ! -f "$v_list" || ! -s "$v_list" ]] && v_do_scan=1

    while true; do
        # 가상환경 검색 및 기존 리스트에 추가 (중복 제외)
        if [[ $v_do_scan -eq 1 ]]; then
            local v_tmp_scan="${v_list}.scan"
            local v_tmp_merge="${v_list}.tmp"
            
            command find "$PWD" -maxdepth 6 -type f \
                \( -path "*/.venv/bin/activate" -o -path "*/venv/bin/activate" -o -path "*/env/bin/activate" \) \
                2>/dev/null > "$v_tmp_scan"
            
            if [[ -s "$v_tmp_scan" ]]; then
                { [[ -f "$v_list" ]] && command cat "$v_list"; command cat "$v_tmp_scan"; } | command grep -v '^$' | command awk '!x[$0]++' > "$v_tmp_merge"
                command mv -f "$v_tmp_merge" "$v_list"
            fi
            command rm -f "$v_tmp_scan" 2>/dev/null
            v_do_scan=0
        fi

        # fzf를 이용한 대화형 선택
        local v_selected=""
        { [[ -f "$v_list" ]] && command cat "$v_list"; command echo "$v_rescan"; } | command fzf \
            --prompt='activate > ' \
            --height=40% \
            --layout=reverse \
            --border \
            --cycle | read -r v_selected

        if [[ -z "$v_selected" ]]; then
            command echo "취소되었습니다."
            return 0
        fi

        if [[ "$v_selected" == "$v_rescan" ]]; then
            v_do_scan=1
            continue
        fi

        # 선택된 파일 유효성 검증
        if [[ ! -f "$v_selected" ]]; then
            command echo "❌ 파일이 존재하지 않습니다: $v_selected"
            continue
        fi

        if [[ -L "$v_selected" ]]; then
            command echo "❌ 심볼릭 링크는 보안상 허용하지 않습니다: $v_selected"
            return 1
        fi

        if [[ ! -O "$v_selected" ]]; then
            command echo "❌ 본인 소유의 파일만 활성화할 수 있습니다: $v_selected"
            return 1
        fi

        if ! command grep -q "VIRTUAL_ENV" "$v_selected"; then
            command echo "❌ 유효한 venv 스크립트가 아닙니다: $v_selected"
            return 1
        fi

        command echo "Sourcing: $v_selected"
        command printf "계속할까요? (y/N): "
        local answer
        read -r answer
        if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
            command echo "취소되었습니다."
            return 0
        fi

        source "$v_selected"
        break
    done
}

activate "$@"
command unfunction activate 2>/dev/null
