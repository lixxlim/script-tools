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
        selected=$(echo "$METADATA" | jq -r "$jq_query" | fzf --prompt="$prompt" --height="$height" --reverse --border)
        # 선택된 값에서 .RELEASE 제거 후 첫 번째 단어(ID) 추출
        echo "$selected" | sed 's/\.RELEASE//g' | awk '{print $1}'
    }

    # 4. 프로젝트 유형, 언어, 부트 버전 선택
    local type language bootVersion
    type=$(select_option '.type.values[] | "\(.id) ( \(.name) )"' "프로젝트 유형 선택: ")
    [[ -z "$type" ]] && return 0
    
    language=$(select_option '.language.values[] | "\(.id) ( \(.name) )"' "언어 선택: ")
    [[ -z "$language" ]] && return 0
    
    # 부트 버전 목록에서도 .RELEASE 제거하여 표시
    bootVersion=$(select_option '.bootVersion.values[] | "\(.id | sub("\\.RELEASE$"; "")) ( \(.name | sub(" \\(RELEASE\\)"; "")) )"' "스프링 부트 버전 선택: ")
    [[ -z "$bootVersion" ]] && return 0

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

    # Description은 공백으로 설정 (입력 생략)
    description=""

    printf "Package Name [$groupId.$artifactId]: "
    read -r packageName
    packageName=${packageName:-$groupId.$artifactId}

    # 6. 자바 버전, 패키징 선택
    local javaVersion packaging
    javaVersion=$(select_option '.javaVersion.values[] | "\(.id) ( \(.name) )"' "자바 버전 선택: ")
    [[ -z "$javaVersion" ]] && return 0
    
    packaging=$(select_option '.packaging.values[] | "\(.id) ( \(.name) )"' "패키징 방식 선택: ")
    [[ -z "$packaging" ]] && return 0

    # 7. 의존성 선택 (멀티 선택, 프리뷰창에 설명 표시)
    local dependencies
    dependencies=$(echo "$METADATA" | jq -r '.dependencies.values[].values[] | "\(.name) ( \(.id) )\t\(.description)"' | \
        fzf -m \
            --bind 'space:toggle' \
            --delimiter='\t' \
            --with-nth=1 \
            --preview 'echo {2}' \
            --preview-window=down:3:wrap \
            --prompt="의존성 선택 (Space로 다중 선택, Enter로 확정): " \
            --height=60% --reverse --border | \
        awk -F '[()]' '{print $(NF-1)}' | tr -d ' ' | paste -sd "," -)

    # 8. 다운로드 및 압축 해제 위치 확인
    local target_dir
    printf "압축을 풀 디렉토리 명 (엔터 시 현재 폴더에 직접 해제): "
    read -r target_dir

    echo "프로젝트 생성 중..."
    
    local curl_cmd=(
        curl -s "https://start.spring.io/starter.tgz"
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

    if [[ -z "$target_dir" ]]; then
        # 입력이 없으면 현재 폴더에 직접 해제 (최상위 디렉토리 스트립)
        "${curl_cmd[@]}" | tar -xzvf - --strip-components=1
    else
        # 입력이 있으면 해당 이름의 폴더를 생성하여 해제
        "${curl_cmd[@]}" -d "baseDir=$target_dir" | tar -xzvf -
    fi

    echo ""
    echo "성공: 프로젝트 생성이 완료되었습니다."
}

spring_init "$@"
unset -f spring_init
