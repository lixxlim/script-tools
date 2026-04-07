# Spring Initializr API를 사용하여 Spring Boot 프로젝트를 대화형으로 생성합니다. (curl, fzf, jq 필요)

spring_init() {
    # 1. 의존성 확인
    local deps=("curl" "fzf" "jq" "tar")
    for d in "${deps[@]}"; do
        if ! command -v "$d" >/dev/null 2>&1; then
            echo "Error: $d 가 설치되어 있지 않습니다. ($d 를 설치해주세요.)"
            return 1 2>/dev/null || exit 1
        fi
    done

    # 2. 메타데이터 가져오기
    echo "Spring Initializr 메타데이터를 가져오는 중..."
    local METADATA
    METADATA=$(curl -s -H "Accept: application/vnd.initializr.v2.1+json" https://start.spring.io/metadata/client)
    if [[ -z "$METADATA" ]] || ! echo "$METADATA" | jq -e . >/dev/null 2>&1; then
        echo "Error: 메타데이터를 가져오는데 실패했거나 응답이 올바른 JSON 형식이 아닙니다."
        return 1 2>/dev/null || exit 1
    fi

    # 3. 옵션 선택 함수
    select_option() {
        local jq_query="$1"
        local prompt="$2"
        local height="${3:-40%}"
        local selected
        # ID와 이름을 탭으로 구분하여 가져와서 fzf로 선택
        selected=$(echo "$METADATA" | jq -r "$jq_query" | fzf --prompt="$prompt" --height="$height" --reverse --border --delimiter='\t' --with-nth=2)
        [[ -z "$selected" ]] && return 1
        # 탭 이전의 ID만 추출
        echo "$selected" | awk -F'\t' '{print $1}'
    }

    # 4. 프로젝트 유형, 언어, 부트 버전 선택
    local type language bootVersion
    type=$(select_option '.type.values[] | select(.tags.format == "project") | "\(.id)\t\(.name)"' "프로젝트 유형 선택: ") || return 0
    language=$(select_option '.language.values[] | "\(.id)\t\(.name)"' "언어 선택: ") || return 0
    bootVersion=$(select_option '.bootVersion.values[] | "\(.id | sub(".RELEASE$"; ""))\t\(.name)"' "스프링 부트 버전 선택: ") || return 0

    # 5. 텍스트 입력들
    local groupId artifactId name description packageName
    printf "Group ID [com.example]: "
    read -r groupId
    groupId=${groupId:-com.example}

    printf "Artifact ID [demo]: "
    read -r artifactId
    artifactId=${artifactId:-demo}

    # Project Name은 Artifact ID와 동일하게 설정 (입력 생략)
    name="$artifactId"

    # Description은 기본값 설정 (입력 생략)
    description="Demo project for Spring Boot"

    printf "Package Name [$groupId.$artifactId]: "
    read -r packageName
    packageName=${packageName:-$groupId.$artifactId}

    # 6. 자바 버전, 패키징 선택
    local javaVersion packaging
    javaVersion=$(select_option '.javaVersion.values[] | "\(.id)\t\(.name)"' "자바 버전 선택: ") || return 0
    packaging=$(select_option '.packaging.values[] | "\(.id)\t\(.name)"' "패키징 방식 선택: ") || return 0

    # 7. 설정 파일 형식 선택 (Properties / YAML)
    local configFormat
    configFormat=$(printf "properties\tProperties\nyaml\tYAML" | fzf --prompt="설정 파일 형식 선택: " --height=20% --reverse --border --delimiter='\t' --with-nth=2 | awk -F'\t' '{print $1}')
    configFormat=${configFormat:-properties}

    # 8. 의존성 선택 (멀티 선택, 프리뷰창에 설명 표시)
    local dependencies
    dependencies=$(echo "$METADATA" | jq -r '.dependencies.values[].values[] | "\(.id)\t\(.name) ( \(.id) )\t\(.description)"' | \
        fzf -m \
            --bind 'space:toggle' \
            --delimiter='\t' \
            --with-nth=2 \
            --preview 'echo {3}' \
            --preview-window=down:3:wrap \
            --prompt="의존성 선택 (Space로 다중 선택, Enter로 확정): " \
            --height=60% --reverse --border | \
        awk -F'\t' '{print $1}' | paste -sd "," -)

    # 9. 다운로드 및 압축 해제 위치 확인
    local target_dir
    printf "압축을 풀 디렉토리 명 (엔터 시 현재 폴더에 직접 해제): "
    read -r target_dir

    echo "프로젝트 생성 중..."
    
    local tmp_file
    tmp_file=$(mktemp)
    
    local curl_args=(
        -s -w "%{http_code}" -o "$tmp_file"
        "https://start.spring.io/starter.tgz"
        -d "type=$type"
        -d "language=$language"
        -d "bootVersion=$bootVersion"
        -d "groupId=$groupId"
        -d "artifactId=$artifactId"
        -d "name=$name"
        -d "description=$description"
        -d "packageName=$packageName"
        -d "javaVersion=$javaVersion"
        -d "packaging=$packaging"
        -d "dependencies=$dependencies"
    )

    [[ -n "$target_dir" ]] && curl_args+=(-d "baseDir=$target_dir")

    local http_code
    http_code=$(curl "${curl_args[@]}")

    if [[ "$http_code" -ne 200 ]]; then
        echo "Error: 프로젝트 생성에 실패했습니다. (HTTP Code: $http_code)"
        if [[ -f "$tmp_file" ]]; then
            cat "$tmp_file"
            echo ""
            command rm -f "$tmp_file"
        fi
        return 1
    fi

    # 압축 해제
    tar -xzvf "$tmp_file"

    # YAML 선택 시 파일명 변경
    if [[ "$configFormat" == "yaml" ]]; then
        local base_path
        if [[ -n "$target_dir" ]]; then
            base_path="$target_dir"
        else
            base_path="."
        fi
        
        local prop_file="$base_path/src/main/resources/application.properties"
        local yaml_file="$base_path/src/main/resources/application.yml"
        
        if [[ -f "$prop_file" ]]; then
            command mv "$prop_file" "$yaml_file"
            echo "설정 파일을 application.yml로 변경했습니다."
        fi
    fi

    command rm -f "$tmp_file"

    echo ""
    echo "성공: 프로젝트 생성이 완료되었습니다."
}

spring_init "$@"
unset -f spring_init
