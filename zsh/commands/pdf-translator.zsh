# PDF 파일을 텍스트로 추출하여 번역합니다. (Python, PyMuPDF, fzf 필요)
pdf_translator() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: fzf가 설치되어 있지 않습니다. (brew install fzf)"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3가 설치되어 있지 않습니다."
        return 1
    fi

    # PyMuPDF(fitz) 설치 여부 확인
    if ! python3 -c "import fitz" >/dev/null 2>&1; then
        echo "Error: 'pymupdf' 라이브러리가 설치되어 있지 않습니다."
        echo "설치 명령어: pip install pymupdf"
        return 1
    fi

    python3 - <<'EOF'
import os
import sys
import subprocess
import json
import time
import urllib.request
import urllib.parse
import re
import fitz  # PyMuPDF

def run_fzf(options, prompt):
    """fzf를 실행하여 선택된 항목을 반환합니다."""
    newline = chr(10)
    try:
        process = subprocess.Popen(
            ['fzf', '--prompt', prompt, '--height', '40%', '--reverse'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, _ = process.communicate(input=newline.join(options))
        return stdout.strip()
    except FileNotFoundError:
        print("Error: 'fzf'가 시스템에 설치되어 있지 않습니다.")
        sys.exit(1)

def extract_text_from_pdf(pdf_path):
    """PDF에서 텍스트를 추출합니다."""
    newline = chr(10)
    print(f"{newline}[1/2] PDF에서 텍스트 추출 중: {pdf_path}")
    doc = fitz.open(pdf_path)
    text = ""
    for page in doc:
        text += page.get_text()
    
    # 간단한 텍스트 정제
    text = re.sub(r'===== PAGE \d+ =====' + newline, '', text)
    text = re.sub(r'(?m)^\s*\d+\s*$' + newline, '', text)
    return text

def translate_google(text, target_lang, source_lang='ja'):
    """Google Translate gtx (무료) API를 사용한 번역"""
    if not text.strip(): return text
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q=" + urllib.parse.quote(text)
    
    retries = 5
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode('utf-8'))
                return "".join([s[0] for s in data[0] if s[0]])
        except Exception:
            if attempt < retries - 1:
                time.sleep(2)
            else:
                return text

def translate_deepl(text, target_lang, api_key, source_lang='JA'):
    """DeepL API를 사용한 번역"""
    if not text.strip(): return text
    
    deepl_lang_map = {
        'ko': 'KO', 'en': 'EN-US', 'ja': 'JA', 
        'zh-CN': 'ZH', 'zh-TW': 'ZH-HANT',
        'fr': 'FR', 'de': 'DE', 'es': 'ES'
    }
    target = deepl_lang_map.get(target_lang, target_lang.upper())
    
    url = "https://api-free.deepl.com/v2/translate"
    params = {
        'auth_key': api_key,
        'text': text,
        'target_lang': target,
        'source_lang': source_lang.upper()
    }
    
    data = urllib.parse.urlencode(params).encode()
    
    try:
        req = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['translations'][0]['text']
    except Exception as e:
        print(f"\n[DeepL] 에러 발생: {e}")
        return text

def translate_full_text(text, engine, target_lang, api_key=None, source_lang='ja'):
    """전체 텍스트 번역 실행"""
    print(f"[2/2] 번역을 진행합니다.")
    
    chunks = []
    current_chunk = ""
    for line in text.splitlines(keepends=True):
        if len(urllib.parse.quote(current_chunk + line)) > 6000:
            chunks.append(current_chunk)
            current_chunk = line
        else:
            current_chunk += line
    if current_chunk:
        chunks.append(current_chunk)

    results = []
    for i, chunk in enumerate(chunks):
        print(f" -> 청크 [{i+1}/{len(chunks)}] 처리 중...")
        if "DeepL" in engine:
            translated = translate_deepl(chunk, target_lang, api_key, source_lang)
        else:
            translated = translate_google(chunk, target_lang, source_lang)
        results.append(translated)
        time.sleep(1)
    
    return "".join(results)

def main():
    # 1. 환경변수 확인 및 엔진 설정
    deepl_key = os.environ.get('DEEPL_API_KEY')
    engine = "Google Translate"

    if deepl_key:
        engine_choice = run_fzf(["Google Translate (무료)", "DeepL Translate (API)"], "사용할 번역 엔진 선택: ")
        if not engine_choice:
            return
        if "DeepL" in engine_choice:
            engine = "DeepL Translate"
    
    print(f"{engine} 번역 엔진을 사용하여 번역이 진행될 예정입니다.")

    # 2. 현재 폴더의 PDF 파일 목록 가져오기
    pdf_files = sorted([f for f in os.listdir('.') if f.lower().endswith('.pdf')])
    if not pdf_files:
        print("Error: 현재 폴더에 PDF 파일이 없습니다.")
        return

    # 3. PDF 파일 선택 (fzf)
    selected_pdf = run_fzf(pdf_files, "번역할 PDF 선택: ")
    if not selected_pdf:
        return

    # 4. 출력 언어 선택 (fzf)
    languages = {
        "Korean (ko)": "ko", 
        "English (en)": "en", 
        "Japanese (ja)": "ja",
        "Chinese Simplified (zh-CN)": "zh-CN", 
        "Chinese Traditional (zh-TW)": "zh-TW",
        "French (fr)": "fr", 
        "German (de)": "de", 
        "Spanish (es)": "es"
    }
    lang_options = list(languages.keys())
    selected_lang_option = run_fzf(lang_options, "출력 언어 선택: ")
    if not selected_lang_option:
        return
    target_lang = languages[selected_lang_option]

    # 5. 실행
    try:
        raw_text = extract_text_from_pdf(selected_pdf)
        translated_text = translate_full_text(raw_text, engine, target_lang, deepl_key, source_lang='ja')

        # 6. 결과 저장
        base_name = os.path.splitext(selected_pdf)[0]
        output_file = f"{base_name}_{target_lang}.txt"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(translated_text)

        newline = chr(10)
        print(newline + "="*40)
        print(f"결과 파일: {output_file}")
        print("="*40)

    except Exception as e:
        print(f"\n오류 발생: {e}")

if __name__ == "__main__":
    main()
EOF
}

pdf_translator "$@"
unfunction pdf_translator 2>/dev/null
