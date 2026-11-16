"""앱 주소(도메인)를 한 번에 바꾼다.

    python3 tools/set_domain.py mbti.example.com      # 자체 도메인으로
    python3 tools/set_domain.py --github              # GitHub 기본 주소로 되돌리기

바꾸는 곳: index.html 의 SITE(공유·초대·결과 링크), 링크 미리보기 og 태그, CNAME 파일(GitHub Pages 자체 도메인 설정).
DNS 와 카카오 도메인 등록은 docs/systems/domain.md 참고.
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
GH = 'https://kiliuswook.github.io/aigyeol/'

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    arg = sys.argv[1].strip()
    if arg == '--github':
        site, cname = GH, None
    else:
        host = re.sub(r'^https?://', '', arg).strip('/')
        if not re.fullmatch(r'[a-z0-9.-]+\.[a-z]{2,}', host):
            sys.exit('도메인 형식이 아닙니다: ' + arg)
        site, cname = f'https://{host}/', host
    p = ROOT / 'index.html'
    s = p.read_text(encoding='utf-8')
    s, n = re.subn(r"const SITE='[^']*';", f"const SITE='{site}';", s)
    if n != 1:
        sys.exit('index.html 에서 SITE 를 찾지 못했습니다')
    s = re.sub(r'(<meta property="og:image" content=")[^"]*?(assets/og\.png">)', rf'\g<1>{site}\2', s)
    s = re.sub(r'(<meta property="og:url" content=")[^"]*(">)', rf'\g<1>{site}\2', s)
    p.write_text(s, encoding='utf-8')
    c = ROOT / 'CNAME'
    if cname:
        c.write_text(cname + '\n', encoding='utf-8')
    elif c.exists():
        c.unlink()
    print('SITE =', site, '| CNAME =', cname or '(없음)')

main()
