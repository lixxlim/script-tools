# fzf로 음원 파일을 선택해 mlx_whisper로 전사합니다. (python3, fzf, ffmpeg, mlx_whisper 필요)
transcribe() {
    emulate -L zsh
    setopt pipefail

    if ! (( $+commands[fzf] )); then
        echo "Error: fzf가 설치되어 있지 않습니다. (brew install fzf)"
        return 1
    fi

    if ! (( $+commands[ffmpeg] )); then
        echo "Error: ffmpeg가 설치되어 있지 않습니다. (brew install ffmpeg)"
        return 1
    fi

    local python_bin="${MLX_WHISPER_PYTHON:-python3}"
    if [[ "$python_bin" != */* ]] && ! (( $+commands[$python_bin] )); then
        echo "Error: Python 실행 파일을 찾을 수 없습니다: $python_bin"
        return 1
    fi
    if [[ "$python_bin" == */* ]] && [[ ! -x "$python_bin" ]]; then
        echo "Error: Python 실행 파일이 없거나 실행할 수 없습니다: $python_bin"
        return 1
    fi

    "$python_bin" - "$@" <<'PY'
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

SUPPORTED_AUDIO_EXTS = {
    ".wav",
    ".mp3",
    ".m4a",
    ".aac",
    ".flac",
    ".ogg",
    ".opus",
    ".mp4",
    ".mkv",
    ".webm",
    ".mov",
    ".aiff",
    ".aif",
    ".wma",
    ".m4b",
    ".m4p",
}


def format_timecode(seconds: float) -> str:
    try:
        total_ms = max(0, int(round(float(seconds) * 1000)))
    except Exception:
        total_ms = 0

    hours = total_ms // 3_600_000
    remain = total_ms % 3_600_000
    minutes = remain // 60_000
    remain = remain % 60_000
    secs = remain // 1000
    millis = remain % 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def render_timestamped_text(result: dict) -> str:
    segments = result.get("segments") or []
    lines: list[str] = []
    for seg in segments:
        text = str(seg.get("text") or "").strip()
        if not text:
            continue
        start = format_timecode(seg.get("start", 0.0))
        end = format_timecode(seg.get("end", 0.0))
        lines.append(f"[{start} - {end}] {text}")

    if lines:
        return "\n".join(lines)

    text = str(result.get("text") or "").strip()
    return text if text else "[인식된 텍스트 없음]"


def list_audio_files(root: Path, recursive: bool) -> list[Path]:
    if recursive:
        candidates = [p for p in root.rglob("*") if p.is_file()]
    else:
        candidates = [p for p in root.glob("*") if p.is_file()]

    return sorted(
        [p for p in candidates if p.suffix.lower() in SUPPORTED_AUDIO_EXTS],
        key=lambda x: str(x).lower(),
    )


def pick_with_fzf(files: list[Path], root: Path) -> Path | None:
    if not files:
        return None

    if shutil.which("fzf") is None:
        raise RuntimeError("fzf가 설치되어 있지 않습니다. `brew install fzf` 후 다시 시도하세요.")

    relative_lines = [str(p.relative_to(root)) for p in files]
    proc = subprocess.run(
        ["fzf", "--prompt", "audio> ", "--height", "40%", "--reverse"],
        input="\n".join(relative_lines),
        text=True,
        capture_output=True,
        check=False,
    )

    if proc.returncode != 0:
        return None

    selected = proc.stdout.strip()
    if not selected:
        return None
    return root / selected


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="fzf로 음원 파일을 선택해 타임스탬프 전사 txt를 생성합니다."
    )
    parser.add_argument(
        "--dir",
        default=".",
        help="검색 시작 디렉터리 (기본: 현재 디렉터리)",
    )
    parser.add_argument(
        "--no-recursive",
        action="store_true",
        help="현재 폴더만 검색 (하위 폴더 제외)",
    )
    parser.add_argument(
        "--model",
        default="mlx-community/whisper-large-v3-turbo",
        help="mlx_whisper 모델 경로/HF repo",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="언어 코드 힌트 (예: ko, en). 생략 시 자동 추정.",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="출력 txt 경로. 생략 시 <선택파일확장자>.txt (예: sample.m4a.txt)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if shutil.which("ffmpeg") is None:
        print("[ERROR] ffmpeg가 설치되어 있지 않습니다.", file=sys.stderr)
        print("[INFO] 설치가 필요합니다. (예: macOS `brew install ffmpeg`)", file=sys.stderr)
        return 1

    try:
        import mlx_whisper  # type: ignore
    except Exception:
        print("[ERROR] Python 패키지 'mlx_whisper'를 찾을 수 없습니다.", file=sys.stderr)
        print("[INFO] 설치 예시: pip install mlx-whisper", file=sys.stderr)
        return 1

    root = Path(args.dir).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"[ERROR] 디렉터리가 존재하지 않습니다: {root}", file=sys.stderr)
        return 1

    files = list_audio_files(root, recursive=not args.no_recursive)
    if not files:
        print(f"[INFO] 음원 파일을 찾지 못했습니다: {root}")
        return 0

    selected = pick_with_fzf(files, root)
    if selected is None:
        print("[INFO] 선택이 취소되었습니다.")
        return 0

    ext = selected.suffix.lower()
    if ext not in SUPPORTED_AUDIO_EXTS:
        print(f"[ERROR] 지원하지 않는 확장자입니다: {ext}", file=sys.stderr)
        return 1

    out_path = Path(args.out).expanduser().resolve() if args.out else Path(str(selected) + ".txt")

    try:
        kwargs = {"path_or_hf_repo": args.model}
        if args.language:
            kwargs["language"] = args.language
        result = mlx_whisper.transcribe(str(selected), **kwargs)
    except Exception as e:
        print(f"[ERROR] 전사 실패: {e}", file=sys.stderr)
        return 1

    text = render_timestamped_text(result)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text + ("\n" if text else ""), encoding="utf-8")

    print(f"[OK] selected: {selected}")
    print(f"[OK] detected extension: {ext}")
    print(f"[OK] transcript: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
}

transcribe "$@"
unfunction transcribe 2>/dev/null
