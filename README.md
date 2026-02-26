# script-tools

이 저장소는 Bash 및 Zsh 환경을 위한 유틸리티 스크립트 모음입니다. `fzf`를 기반으로 한 대화형 메뉴 시스템을 통해 다양한 도구를 쉽게 실행할 수 있습니다.

## 주요 특징

- **대화형 메뉴 (`cmd`)**: `fzf`를 사용하여 `commands/` 디렉토리 내의 모든 스크립트를 메뉴로 보여주고 실행합니다.
- **자동 감지 및 정렬**: `commands/` 폴더에 스크립트를 추가하면 자동으로 메뉴에 나타나며, 우선순위 설정(`CMD_ORDER`) 및 이름순 정렬을 지원합니다.
- **인코딩 관리**: 파일 인코딩 확인 및 UTF-8 변환 도구를 포함합니다.
- **셸 호환성**: Bash와 Zsh 환경을 모두 지원하며, 각 셸의 특성에 최적화되어 있습니다.

## 설치 및 사용 방법

이 스크립트들을 사용하려면 셸 설정 파일(예: `~/.bashrc`, `~/.bash_profile` 또는 `~/.zshrc`)에 `cmd` 스크립트를 소스해야 합니다. `SCRIPT_TOOLS_PATH`를 이 저장소의 실제 경로로 설정해주세요.

### Bash 스크립트 로드 (.bashrc 또는 .bash_profile)

```bash
# script-tools 저장소의 실제 경로를 설정하세요.
export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

# 메인 cmd 스크립트 로드
if [ -f "$SCRIPT_TOOLS_PATH/bash/cmd.sh" ]; then
  source "$SCRIPT_TOOLS_PATH/bash/cmd.sh"
fi

# 개별 명령어들을 직접 호출하고 싶다면 아래와 같이 로드할 수 있습니다.
for script in "$SCRIPT_TOOLS_PATH"/bash/commands/*.sh; do
  [ -f "$script" ] && source "$script"
done
```

### Zsh 스크립트 로드 (.zshrc)

```zsh
# script-tools 저장소의 실제 경로를 설정하세요.
export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

# 메인 cmd 스크립트 로드
if [ -f "$SCRIPT_TOOLS_PATH/zsh/cmd.zsh" ]; then
  source "$SCRIPT_TOOLS_PATH/zsh/cmd.zsh"
fi

# 개별 명령어들을 직접 호출하고 싶다면 아래와 같이 로드할 수 있습니다.
for script in "$SCRIPT_TOOLS_PATH"/zsh/commands/*.zsh; do
  [ -f "$script" ] && source "$script"
done
```

---

## 명령어 실행 (`cmd`)

터미널에서 `cmd`를 입력하면 대화형 메뉴가 나타납니다. `fzf`를 사용하여 원하는 명령을 검색하고 선택하여 실행할 수 있습니다.

### 기본 명령어 목록

*   `_edit`: `cmd` 스크립트를 직접 편집합니다.
*   `_refresh`: `cmd` 스크립트를 다시 로드하여 변경 사항을 적용합니다.
*   `activate`: 현재 디렉토리 또는 하위 디렉토리의 Python 가상 환경(`activate`)을 찾아 활성화합니다.
*   `check-encode`: 현재 디렉토리 내 파일들의 인코딩을 확인합니다. (`nkf` 필요)
*   `convert-encode-to-utf8`: 현재 디렉토리 내 파일들을 UTF-8로 변환합니다. (`nkf` 필요)
*   `sdk-use-java`: 설치된 Java 버전을 선택하고 SDKMAN!을 통해 즉시 적용합니다. (`fzf`, `sdkman` 필요)

---

## 새로운 명령어 추가 방법

새로운 명령어를 추가하려면 `bash/commands/` 또는 `zsh/commands/` 디렉토리에 스크립트 파일을 생성하기만 하면 됩니다.

1.  **파일 생성**: `bash/commands/my-command.sh` (Bash용) 또는 `zsh/commands/my-command.zsh` (Zsh용).
2.  **설명 추가**: 파일 상단에 `# Description: 명령어 설명` 주석을 추가하면 `cmd` 메뉴에 설명이 표시됩니다.
3.  **메뉴 확인**: `cmd`를 실행하면 새로운 명령어가 자동으로 리스트에 나타납니다.

---

## 전제 조건

*   `fzf`: 대화형 메뉴 선택에 사용됩니다. (`brew install fzf`)
*   `nkf`: 인코딩 확인 및 변환 스크립트에서 사용됩니다. (`brew install nkf`)
*   `sdkman`: `sdk-use-java` 기능을 위해 필요합니다. (https://sdkman.io/ 에서 설치 가능)
