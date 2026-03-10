# script-tools

이 저장소는 Bash 및 Zsh 환경을 위한 유틸리티 스크립트 모음입니다. `fzf`를 기반으로 한 대화형 메뉴 시스템을 통해 다양한 도구를 쉽게 실행할 수 있습니다.

## 주요 특징

- **대화형 메뉴 (`cmd`)**: `fzf`를 사용하여 `commands/` 디렉토리 내의 모든 스크립트를 메뉴로 보여주고 실행합니다.
- **자동 감지 및 정렬**: `commands/` 폴더에 스크립트를 추가하면 자동으로 메뉴에 나타나며, 우선순위 설정(`CMD_ORDER`) 후 나머지 항목 이름순 정렬을 지원합니다.

## 설치 및 사용 방법

이 스크립트들을 사용하려면 셸 설정 파일(예: `~/.bashrc`, `~/.bash_profile` 또는 `~/.zshrc`)에 `cmd` 스크립트를 소스해야 합니다. 아래 예시처럼 `SCRIPT_TOOLS_PATH`를 이 저장소의 실제 경로로 설정하면 편리합니다.

### Bash 스크립트 로드 (.bashrc 또는 .bash_profile)

```bash
# script-tools 저장소의 실제 경로를 설정하세요.
export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

# 메인 cmd 스크립트 로드
if [ -f "$SCRIPT_TOOLS_PATH/bash/cmd.sh" ]; then
  source "$SCRIPT_TOOLS_PATH/bash/cmd.sh"
fi
```

> 참고: `cmd.sh`는 자신의 위치를 기준으로 `commands/*.sh`를 찾습니다.
> 주의: `commands/*.sh` 파일은 `source`될 때 즉시 실행되도록 작성되어 있으므로, 셸 시작 파일에서 일괄 `source`하지 마세요.

### Zsh 스크립트 로드 (.zshrc)

```zsh
# script-tools 저장소의 실제 경로를 설정하세요.
export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"

# 메인 cmd 스크립트 로드
if [ -f "$SCRIPT_TOOLS_PATH/zsh/cmd.zsh" ]; then
  source "$SCRIPT_TOOLS_PATH/zsh/cmd.zsh"
fi
```

> 주의: 마찬가지로 `commands/*.zsh` 파일은 `source`될 때 즉시 실행되도록 작성되어 있으므로, 셸 시작 파일에서 일괄 `source`하지 마세요.

---

## 명령어 실행 (`cmd`)

- 터미널에서 `cmd`를 입력하면 대화형 메뉴가 나타납니다. `fzf`를 사용하여 원하는 명령을 검색하고 선택하여 실행할 수 있습니다.
- 메뉴 표시 순서는 `CMD_ORDER`에 정의된 항목이 먼저 나오고, 나머지 항목이 이름순으로 표시됩니다.
- 특정 명령을 바로 실행하려면 `cmd <명령이름> [인자...]` 형태도 사용할 수 있습니다. 예: `cmd check-encode`

### 현재기준 명령어 목록

#### Bash

- `_edit`: `cmd` 스크립트를 직접 편집하고 저장 후 자동으로 다시 로드하여 변경 사항을 적용합니다.
- `activate`: 현재 디렉토리 또는 하위 디렉토리의 Python 가상 환경(`activate`)을 찾아 선택 후 활성화합니다. 심볼릭 링크/소유자/스크립트 형태를 확인하고 최종 확인 프롬프트를 보여줍니다. (`fzf` 필요)
- `check-encode`: 현재 디렉토리 내 파일들의 인코딩을 확인합니다. (`nkf` 필요)
- `codex`: 한 줄 프롬프트를 입력받아 `codex exec -- "<prompt>"`로 실행합니다. (`codex` 필요, `gum` 있으면 입력 UI 개선)
- `convert-encode-to-utf8`: 현재 디렉토리 내 파일들을 UTF-8로 변환하고, 변경된 파일의 전후 인코딩을 출력합니다. (`nkf` 필요)
- `edit-nginx`: `sudo vi /etc/nginx`로 Nginx 설정을 편집한 뒤, 종료 시 `sudo nginx -t`로 설정 문법을 점검합니다. (`nginx`, `sudo` 권한 필요)
- `gemini`: 한 줄 프롬프트를 입력받아 `gemini -p "<prompt>"`로 실행합니다. (`gemini` 필요, `gum` 있으면 입력/스피너 UI 제공)
- `nvm-use-node`: 설치된 Node.js 버전을 선택하고 `nvm use`로 즉시 전환합니다. (`fzf`, `nvm` 필요)
- `pdf-translator`: PDF 파일을 텍스트로 추출하여 번역합니다. (`python3`, `pymupdf`, `fzf` 필요)
- `sdk-use-java`: 설치된 Java 버전을 선택하고 SDKMAN!을 통해 즉시 적용합니다. (`fzf`, `sdkman` 필요)

#### Zsh

- `activate`: 현재 디렉토리/하위 디렉토리에서 Python venv `activate` 파일을 찾아 선택 후 활성화합니다. 소유권/심볼릭 링크/스크립트 형태 검증과 확인 프롬프트를 포함합니다. (`fzf` 필요)
- `check-encode`: 현재 디렉토리 파일 인코딩을 출력합니다. (`nkf` 필요)
- `codex`: 한 줄 프롬프트를 받아 `codex exec -- "<prompt>"`를 실행합니다. (`codex` 필요, `gum` 있으면 입력 UI 개선)
- `convert-encode-to-utf8`: 현재 디렉토리 파일을 UTF-8로 변환하고, 변경된 파일의 전후 인코딩을 출력합니다. (`nkf` 필요)
- `gemini`: 한 줄 프롬프트를 받아 `gemini -p "<prompt>"`를 실행합니다. (`gemini` 필요, `gum` 있으면 입력/스피너 UI 제공)
- `git-check`: 현재 저장소의 브랜치를 `fzf`로 선택해 `git switch`를 실행합니다. (`fzf` 필요)
- `idea`: macOS에서 현재 디렉토리를 IntelliJ IDEA로 엽니다.
- `jules_commander`: Jules CLI를 사용하여 리모트 세션 및 레포지토리를 관리하는 대화형 메뉴를 제공합니다.
- `nvm-use-node`: 설치된 Node.js 버전을 `fzf`로 선택해 `nvm use`로 전환합니다. (`nvm`, `fzf` 필요)
- `pdf-translator`: PDF 텍스트를 추출해 번역하고 결과를 텍스트 파일로 저장합니다. (`python3`, `pymupdf`, `fzf` 필요)
- `print-openrouter-key-limits`: `OPENROUTER_API_KEY`로 OpenRouter 키 사용량/한도 정보를 조회합니다. (`curl` 필요)
- `run-claude-code-with-openrouter`: OpenRouter free 모델을 조회/선택해 Claude Code를 실행합니다. 모델 목록(`list`) 조회와 직접 모델 지정 실행도 지원합니다. (`OPENROUTER_API_KEY`, `claude`, `curl`, `jq`, `fzf` 필요)
- `sdk-use-java`: 설치된 Java 후보를 선택해 SDKMAN 기본 버전으로 전환합니다. (`sdkman`, `gum` 또는 `fzf` 필요)
- `transcribe`: 음원 파일을 `fzf`로 선택해 `mlx_whisper`로 전사하고 타임스탬프 텍스트 파일을 생성합니다. (`python3`, `ffmpeg`, `fzf`, `mlx-whisper` 필요)

---

## 새로운 명령어 추가 방법

새로운 명령어를 추가하려면 `bash/commands/` 또는 `zsh/commands/` 디렉토리에 스크립트 파일을 생성하기만 하면 됩니다.

1. **파일 생성**: `bash/commands/my-command.sh` (Bash용) 또는 `zsh/commands/my-command.zsh` (Zsh용).
2. **설명 추가**: 파일 상단의 첫 `# 명령어 설명` 주석 줄이 `cmd` 메뉴 설명으로 표시됩니다.
3. **실행 코드 작성**: 이 프로젝트의 커맨드 파일은 `source`될 때 즉시 실행되는 형태이므로, 파일 하단에 실행 진입점(예: 함수 호출)을 포함해야 합니다.
4. **메뉴 확인**: `cmd`를 실행하면 새로운 명령어가 자동으로 리스트에 나타납니다.

---

## 커맨드 구동에 사용되는 라이브러리

- `fzf`: 대화형 메뉴 선택에 사용됩니다. (`brew install fzf`)
- `gum` (선택): `codex`, `gemini` 명령의 한 줄 입력 UI 및 스피너 표시를 제공합니다. (`brew install gum`)
- `nkf`: 인코딩 확인 및 변환 스크립트에서 사용됩니다. (`brew install nkf`)
- `python3`: `pdf-translator`, `transcribe` 명령 실행에 필요합니다.
- `pymupdf` (Python 라이브러리): PDF 텍스트 추출에 필요합니다. (`pip install pymupdf`)
- `ffmpeg`: `transcribe`에서 오디오 전처리/디코딩에 필요합니다. (`brew install ffmpeg`)
- `mlx-whisper` (Python 라이브러리): `transcribe` 전사 실행에 필요합니다. (`pip install mlx-whisper`)
- `codex`: `codex` 명령 실행에 필요합니다.
- `gemini`: `gemini` 명령 실행에 필요합니다.
- `nvm`: `nvm-use-node` 기능을 위해 필요합니다. (https://github.com/nvm-sh/nvm 에서 설치 가능)
- `sdkman`: `sdk-use-java` 기능을 위해 필요합니다. (https://sdkman.io/ 에서 설치 가능)
