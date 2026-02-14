# script-tools

이 저장소는 Bash 및 Zsh 환경을 위한 유틸리티 스크립트 모음입니다.

## 사용 방법

이 스크립트들을 사용하려면 셸 설정 파일(예: `~/.bashrc`, `~/.bash_profile` 또는 `~/.zshrc`)에 스크립트를 소스해야 합니다. 각 스크립트를 개별적으로 소스하는 대신, 다음 코드 스니펫을 사용하여 해당 폴더 내의 모든 스크립트를 자동으로 로드할 수 있습니다. `SCRIPT_TOOLS_PATH`를 이 저장소의 실제 경로로 변경해주세요.

### Bash 스크립트 로드 (.bashrc 또는 .bash_profile)



```bash

# script-tools 저장소의 실제 경로를 설정하세요.

export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"



for script in "$SCRIPT_TOOLS_PATH"/bash/*.sh; do

  if [ -f "$script" ]; then

    source "$script"

  fi

done

```



### Zsh 스크립트 로드 (.zshrc)



```zsh

# script-tools 저장소의 실제 경로를 설정하세요.

export SCRIPT_TOOLS_PATH="/path/to/your/script-tools"



for script in "$SCRIPT_TOOLS_PATH"/zsh/*.zsh; do

  if [ -f "$script" ]; then

    source "$script"

  fi

done

```



---



## Bash 스크립트



이 섹션은 Bash 사용자를 위한 스크립트를 설명합니다.



### 인코딩 관련 스크립트 (`check-encode.sh`, `convert-encode-to-utf8.sh`)

*   **스크립트명**: `check-encode.sh` (함수: `check-encode`), `convert-encode-to-utf8.sh` (함수: `convert_encode_to_utf8`)

*   **전제 조건**: `nkf` (macOS에서는 `brew install nkf`로 설치 가능)

*   **개요**:

    *   `check-encode.sh`: 현재 디렉토리 내 모든 파일의 문자 인코딩을 감지하고 출력합니다.

    *   `convert-encode-to-utf8.sh`: 현재 디렉토리 내 모든 파일의 문자 인코딩을 UTF-8로 변환합니다.

*   **결과**:

    *   `check-encode.sh`: 각 파일에 대해 파일명과 감지된 인코딩을 출력합니다 (예: `my_file.txt: UTF-8`).

    *   `convert-encode-to-utf8.sh`: 인코딩이 변경된 각 파일에 대해 파일명과 인코딩 변경 내역을 출력합니다 (예: `my_file.txt: EUC-KR → UTF-8`).



### `cmd.sh` (함수: `cmd`)

*   **전제 조건**: `fzf` (macOS에서는 `brew install fzf`로 설치 가능)

*   **개요**: `fzf`를 사용하여 미리 정의된 하위 명령들을 실행하기 위한 대화형 메뉴를 제공합니다.

    *   `_edit`: `cmd.sh` 스크립트를 `vi`로 열어 편집합니다.

    *   `_refresh`: `cmd.sh` 스크립트를 다시 로드하여 최근 변경 사항을 적용합니다.

    *   `activate`: 현재 디렉토리에서 `activate` 스크립트를 찾아 소스합니다 (일반적으로 Python 가상 환경에 사용됩니다).

*   **결과**: 선택된 하위 명령을 실행합니다. `activate`의 경우 가상 환경을 활성화합니다.



---



## Zsh 스크립트



이 섹션은 Zsh 사용자를 위한 스크립트를 설명합니다.



### 인코딩 관련 스크립트 (`check-encode.zsh`, `convert-encode-to-utf8.zsh`)

*   **스크립트명**: `check-encode.zsh` (함수: `check-encode`), `convert-encode-to-utf8.zsh` (함수: `convert_encode_to_utf8`)

*   **전제 조건**: `nkf` (macOS에서는 `brew install nkf`로 설치 가능)

*   **개요**:

    *   `check-encode.zsh`: 현재 디렉토리 내 모든 파일의 문자 인코딩을 감지하고 출력합니다.

    *   `convert-encode-to-utf8.zsh`: 현재 디렉토리 내 모든 파일의 문자 인코딩을 UTF-8로 변환합니다.

*   **결과**:

    *   `check-encode.zsh`: 각 파일에 대해 파일명과 감지된 인코딩을 출력합니다 (예: `my_file.txt: UTF-8`).

    *   `convert-encode-to-utf8.zsh`: 인코딩이 변경된 각 파일에 대해 파일명과 인코딩 변경 내역을 출력합니다 (예: `my_file.txt: EUC-KR → UTF-8`).



### `cmd.zsh` (함수: `cmd`)

*   **전제 조건**: `fzf` (macOS에서는 `brew install fzf`로 설치 가능)

*   **개요**: `fzf`를 사용하여 미리 정의된 하위 명령들을 실행하기 위한 대화형 메뉴를 제공합니다.

    *   `_edit`: `cmd.zsh` 스크립트를 `vi`로 열어 편집합니다.

    *   `_refresh`: `cmd.zsh` 스크립트를 다시 로드하여 최근 변경 사항을 적용합니다.

    *   `activate`: 현재 디렉토리에서 `activate` 스크립트를 찾아 소스합니다 (일반적으로 Python 가상 환경에 사용됩니다).

*   **결과**: 선택된 하위 명령을 실행합니다. `activate`의 경우 가상 환경을 활성화합니다.
