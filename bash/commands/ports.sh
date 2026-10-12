# 현재 리스닝 포트를 표 형태로 출력합니다. (fzf 필터 지원, 색상 구분, 포트 번호순 정렬)
ports() {
    # ── prerequisite check ──────────────────────────────────────────────────
    local ss_cmd=""
    if command -v ss >/dev/null 2>&1; then
        ss_cmd="ss"
    elif command -v netstat >/dev/null 2>&1; then
        ss_cmd="netstat"
    else
        echo "❌ ss 또는 netstat이 필요합니다."
        return 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ fzf가 없습니다: brew install fzf"
        return 1
    fi

    # ── fzf 필터 선택 ───────────────────────────────────────────────────────
    local selected_filter
    selected_filter=$(printf '%s\n' \
        "전체 표시 (필터 없음)" \
        "TCP만" \
        "UDP만" \
        "IPv4만" \
        "IPv6만" \
        "TCP + IPv4만" \
        "TCP + IPv6만" \
        "UDP + IPv4만" \
        "UDP + IPv6만" \
        | fzf \
            --prompt="필터 선택 > " \
            --header="Enter: 선택 / Esc: 전체 표시" \
            --height=40% \
            --reverse \
            --no-multi) || true

    # Esc 또는 미선택 시 기본값(전체 표시)
    [[ -z "$selected_filter" ]] && selected_filter="전체 표시 (필터 없음)"

    # ── ss/netstat 실행 (sudo 우선 시도, 실패 시 일반 실행으로 fallback) ──────
    local raw_data=""
    local used_sudo=0
    if [[ "$ss_cmd" == "ss" ]]; then
        if sudo -n ss -tunlp >/dev/null 2>&1; then
            raw_data=$(sudo ss -tunlp 2>/dev/null)
            used_sudo=1
        else
            raw_data=$(ss -tunlp 2>/dev/null)
        fi
    else
        if sudo -n netstat -tunlp >/dev/null 2>&1; then
            raw_data=$(sudo netstat -tunlp 2>/dev/null)
            used_sudo=1
        else
            raw_data=$(netstat -tunlp 2>/dev/null)
        fi
    fi

    # ── awk로 파싱 + 색상 + 포트순 정렬 + 표 렌더링 (mawk 호환) ───────────────
    echo "$raw_data" | awk -v filter="$selected_filter" -v used_sudo="$used_sudo" '
    BEGIN {
        RESET    = "\033[0m"
        BOLD     = "\033[1m"
        C_PORT   = "\033[38;5;226m"   # 노란색 (포트 번호)
        C_TCP    = "\033[38;5;39m"    # 파란색 (TCP)
        C_UDP    = "\033[38;5;208m"   # 주황색 (UDP)
        C_LISTEN = "\033[38;5;82m"    # 초록색
        C_UNCONN = "\033[38;5;220m"   # 노란색
        C_OTHER  = "\033[38;5;245m"   # 회색
        C_ALL    = "\033[38;5;198m"   # 분홍 (0.0.0.0 / :: 전체 개방)
        C_LO     = "\033[38;5;245m"   # 회색 (127.x / ::1 로컬)
        C_NRM    = "\033[38;5;255m"   # 흰색 (그 외)
        C_PROC   = "\033[38;5;147m"   # 연보라
        C_PID    = "\033[38;5;245m"   # 회색
        row_count = 0
        col1 = col2 = col3 = col4 = col5 = 0
    }

    /^Netid/ || /^Proto/ { next }
    NF < 5 { next }

    {
        proto  = tolower($1)
        status = $2
        local  = $5

        # 프로세스 정보 파싱 (mawk 호환: 3인수 match 불가)
        proc_raw = ""
        for (i = 7; i <= NF; i++) proc_raw = proc_raw " " $i
        gsub(/^ /, "", proc_raw)

        proc_name = "-"
        proc_pid  = ""
        tmp = proc_raw
        if (match(tmp, /users:\(\("[^"]+"/)) {
            pn = substr(tmp, RSTART, RLENGTH)
            sub(/users:\(\("/, "", pn)
            sub(/"$/, "", pn)
            proc_name = pn
        }
        if (match(tmp, /pid=[0-9]+/)) {
            pp = substr(tmp, RSTART, RLENGTH)
            sub(/pid=/, "", pp)
            proc_pid = pp
        }

        # 마지막 콜론(:) 위치를 찾아 주소와 포트 분리
        last_colon = 0
        len_local = length(local)
        for (k = len_local; k >= 1; k--) {
            if (substr(local, k, 1) == ":") {
                last_colon = k
                break
            }
        }

        addr = local
        port = ""
        if (last_colon > 0) {
            addr = substr(local, 1, last_colon - 1)
            port = substr(local, last_colon + 1)
        }

        # IPv4 / IPv6 구분 (주소에 : 가 있거나 [ 로 시작하면 IPv6)
        is_v6 = (addr ~ /^\[/ || addr ~ /:/)
        is_v4 = (1 - is_v6)

        # ── 필터 적용 ─────────────────────────────────────────────────────
        if (filter == "TCP만"         && proto != "tcp")              next
        if (filter == "UDP만"         && proto != "udp")              next
        if (filter == "IPv4만"        && !is_v4)                      next
        if (filter == "IPv6만"        && !is_v6)                      next
        if (filter == "TCP + IPv4만"  && (proto != "tcp" || !is_v4))  next
        if (filter == "TCP + IPv6만"  && (proto != "tcp" || !is_v6))  next
        if (filter == "UDP + IPv4만"  && (proto != "udp" || !is_v4))  next
        if (filter == "UDP + IPv6만"  && (proto != "udp" || !is_v6))  next

        # ── 데이터 저장 ───────────────────────────────────────────────────
        row_count++
        r_port[row_count]   = port
        r_proto[row_count]  = proto
        r_status[row_count] = status
        r_addr[row_count]   = addr
        r_pname[row_count]  = proc_name
        r_ppid[row_count]   = proc_pid

        proc_col = proc_name (proc_pid != "" ? " (" proc_pid ")" : "")
        r_pcol[row_count] = proc_col

        if (length(port)     > col1) col1 = length(port)
        if (length(proto)    > col2) col2 = length(proto)
        if (length(status)   > col3) col3 = length(status)
        if (length(addr)     > col4) col4 = length(addr)
        if (length(proc_col) > col5) col5 = length(proc_col)
    }

    END {
        if (row_count == 0) {
            print "해당 조건의 포트가 없습니다."
            exit
        }

        # ── 포트 번호(숫자) 기준 정렬 (Shell Sort) ───────────────────────
        for (r = 1; r <= row_count; r++) order[r] = r

        gap = int(row_count / 2)
        while (gap > 0) {
            for (i = gap + 1; i <= row_count; i++) {
                temp = order[i]
                j = i
                while (j > gap) {
                    idx_prev = order[j - gap]
                    p1 = r_port[temp] + 0
                    p2 = r_port[idx_prev] + 0
                    # 포트 번호 오름차순, 같으면 프로토콜 순
                    if (p2 > p1 || (p2 == p1 && r_proto[idx_prev] > r_proto[temp])) {
                        order[j] = idx_prev
                        j -= gap
                    } else {
                        break
                    }
                }
                order[j] = temp
            }
            gap = int(gap / 2)
        }

        # 헤더 최소 너비 보장
        H1 = "PORT"; H2 = "PROTOCOL"; H3 = "STATUS"; H4 = "ADDRESS"; H5 = "PROCESS"
        if (length(H1) > col1) col1 = length(H1)
        if (length(H2) > col2) col2 = length(H2)
        if (length(H3) > col3) col3 = length(H3)
        if (length(H4) > col4) col4 = length(H4)
        if (length(H5) > col5) col5 = length(H5)
        col1 += 2; col2 += 2; col3 += 2; col4 += 2; col5 += 2

        # 가로선 문자열 생성
        l1 = ""; l2 = ""; l3 = ""; l4 = ""; l5 = ""
        for (i = 1; i <= col1; i++) l1 = l1 "─"
        for (i = 1; i <= col2; i++) l2 = l2 "─"
        for (i = 1; i <= col3; i++) l3 = l3 "─"
        for (i = 1; i <= col4; i++) l4 = l4 "─"
        for (i = 1; i <= col5; i++) l5 = l5 "─"

        # ── 상단 테두리 ───────────────────────────────────────────────────
        print BOLD "┌" l1 "┬" l2 "┬" l3 "┬" l4 "┬" l5 "┐" RESET

        # ── 헤더 ─────────────────────────────────────────────────────────
        printf BOLD "│ %-*s │ %-*s │ %-*s │ %-*s │ %-*s │" RESET "\n", \
            col1-2, H1, col2-2, H2, col3-2, H3, col4-2, H4, col5-2, H5

        print BOLD "├" l1 "┼" l2 "┼" l3 "┼" l4 "┼" l5 "┤" RESET

        # ── 데이터 행 (정렬 순서대로 출력, 포트별 그룹 구분) ─────────────
        prev_port = ""
        for (m = 1; m <= row_count; m++) {
            r      = order[m]
            port   = r_port[r]
            proto  = r_proto[r]
            status = r_status[r]
            addr   = r_addr[r]
            pname  = r_pname[r]
            ppid   = r_ppid[r]
            pcol   = r_pcol[r]

            # 포트가 변경되면 그룹 구분선 출력
            if (m > 1 && port != prev_port) {
                print "├" l1 "┼" l2 "┼" l3 "┼" l4 "┼" l5 "┤"
            }
            prev_port = port

            # 프로토콜 색
            if (proto == "tcp")      cp = C_TCP
            else if (proto == "udp") cp = C_UDP
            else                     cp = C_OTHER

            # 상태 색
            if (status == "LISTEN")      cs = C_LISTEN
            else if (status == "UNCONN") cs = C_UNCONN
            else                         cs = C_OTHER

            # 주소 색
            if (addr == "0.0.0.0" || addr == "[::]" || addr == "*")
                ca = C_ALL
            else if (addr ~ /^127\./ || addr == "[::1]")
                ca = C_LO
            else
                ca = C_NRM

            # 프로세스 표시
            if (ppid != "")
                proc_str = C_PROC pname RESET " " C_PID "(" ppid ")" RESET
            else
                proc_str = C_PROC pname RESET

            proto_disp = toupper(proto)

            # 패딩 생성
            pp1 = ""; pp2 = ""; sp = ""; ap = ""; prp = ""
            n1 = col1-2-length(port)
            n2 = col2-2-length(proto_disp)
            n3 = col3-2-length(status)
            n4 = col4-2-length(addr)
            n5 = col5-2-length(pcol)
            for (i=0; i<n1; i++) pp1 = pp1 " "
            for (i=0; i<n2; i++) pp2 = pp2 " "
            for (i=0; i<n3; i++) sp  = sp  " "
            for (i=0; i<n4; i++) ap  = ap  " "
            for (i=0; i<n5; i++) prp = prp " "

            print "│ " C_PORT port RESET pp1 \
                  " │ " cp proto_disp RESET pp2 \
                  " │ " cs status RESET sp \
                  " │ " ca addr RESET ap \
                  " │ " proc_str prp " │"
        }

        # ── 하단 테두리 ───────────────────────────────────────────────────
        print BOLD "└" l1 "┴" l2 "┴" l3 "┴" l4 "┴" l5 "┘" RESET

        printf "  총 %d개 항목  [필터: %s]", row_count, filter
        if (!used_sudo)
            printf "  \033[38;5;220m⚠ sudo 없이 실행 중 — 타인 프로세스는 \"-\"로 표시될 수 있습니다\033[0m"
        print ""

        # ── 색상 범례 ─────────────────────────────────────────────────────
        print ""
        print BOLD "  색상 범례" RESET
        print "  " C_PORT     "■" RESET " 포트 번호      " \
              C_TCP           "■" RESET " TCP 프로토콜   " \
              C_UDP           "■" RESET " UDP 프로토콜"
        print "  " C_LISTEN   "■" RESET " LISTEN 상태    " \
              C_UNCONN        "■" RESET " UNCONN 상태    " \
              C_OTHER         "■" RESET " 기타 상태"
        print "  " C_ALL      "■" RESET " 전체 개방 주소 (0.0.0.0 / [::])   " \
              C_LO            "■" RESET " 로컬 전용 (127.x / [::1])   " \
              C_NRM           "■" RESET " 특정 IP"
        print "  " C_PROC     "■" RESET " 프로세스명     " \
              C_PID           "■" RESET " PID"
    }
    '
}

ports "$@"
unset -f ports
