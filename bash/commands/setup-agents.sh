# 에이전트 설정 디렉토리(~/.agents 등)를 생성하고 AGENTS.md 심볼릭 링크를 구성합니다.
_setup_agents_bash() {
    local agents_dir="$HOME/.agents"
    local agents_file="$agents_dir/AGENTS.md"
    local skills_dir="$agents_dir/skills"
    local claude_dir="$HOME/.claude"
    local codex_dir="$HOME/.codex"
    local gemini_dir="$HOME/.gemini"

    # 1. ~/.agents 디렉토리 체크 및 생성
    if [ ! -d "$agents_dir" ]; then
        mkdir -p "$agents_dir"
        echo "✅ 생성됨: $agents_dir"
    fi

    # 2. ~/.agents/AGENTS.md 파일 체크 및 생성
    if [ ! -f "$agents_file" ]; then
        touch "$agents_file"
        echo "✅ 생성됨: $agents_file"
    fi

    # 3. ~/.agents/skills 디렉토리 체크 및 생성
    if [ ! -d "$skills_dir" ]; then
        mkdir -p "$skills_dir"
        echo "✅ 생성됨: $skills_dir"
    fi

    # 4. 에이전트별 디렉토리 체크 및 생성
    for dir in "$claude_dir" "$codex_dir" "$gemini_dir"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "✅ 생성됨: $dir"
        fi
    done

    # 5. 스킬 디렉토리 마이그레이션 및 심볼릭 링크 설정
    for dir in "$claude_dir" "$codex_dir" "$gemini_dir"; do
        local target_skills="$dir/skills"
        if [ -d "$target_skills" ] && [ ! -L "$target_skills" ]; then
            echo "📦 스킬 디렉토리 발견: $target_skills"
            # 기존 내용 이동 (이미 존재하면 덮어쓰지 않음)
            cp -rn "$target_skills/"* "$skills_dir/" 2>/dev/null
            rm -rf "$target_skills"
            ln -s "$skills_dir" "$target_skills"
            echo "🔗 마이그레이션 및 링크 완료: $target_skills -> $skills_dir"
        elif [ ! -e "$target_skills" ]; then
            ln -s "$skills_dir" "$target_skills"
            echo "🔗 스킬 링크 생성됨: $target_skills -> $skills_dir"
        fi
    done

    # 6. 심볼릭 링크 생성 설정
    # 대상 파일과 소스 파일의 쌍
    local -a targets=(
        "$claude_dir/CLAUDE.md"
        "$codex_dir/AGENTS.md"
        "$gemini_dir/GEMINI.md"
    )

    for target in "${targets[@]}"; do
        if [ -e "$target" ] || [ -L "$target" ]; then
            # 이미 존재하면 (심볼릭 링크 포함) 확인
            printf "⚠️ 파일이 이미 존재합니다: %s\n덮어쓰시겠습니까? (y/N): " "$target"
            read -r answer
            if [[ "$answer" =~ ^[Yy]$ ]]; then
                rm -rf "$target"
                ln -s "$agents_file" "$target"
                echo "🚀 덮어쓰기 완료: $target -> $agents_file"
            else
                echo "⏭️ 건너뜀: $target"
            fi
        else
            ln -s "$agents_file" "$target"
            echo "🔗 링크 생성됨: $target -> $agents_file"
        fi
    done
}

_setup_agents_bash "$@"
unset -f _setup_agents_bash
