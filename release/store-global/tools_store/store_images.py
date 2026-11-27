"""플레이 등록정보 그림 교체: 아이콘·피처 그래픽·휴대전화(·태블릿) 스크린샷. 등록정보 글자는 바꾸지 않는다.
  python store_images.py show            # 언어별 이미지 수(읽기만)
  python store_images.py push [--validate]
인증: ~/.claude/tools/play/play_auth.py (gcloud 대리, 키 파일 없음)."""
import glob, os, sys
sys.path.insert(0, os.path.expanduser('~/.claude/tools/play'))
from play_auth import session  # noqa: E402
PKG = 'kr.co.wonderwheel.childmbti'
API = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}'
UP = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}'
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # release/store-global
TYPES = ['icon', 'featureGraphic', 'phoneScreenshots', 'sevenInchScreenshots', 'tenInchScreenshots', 'promoGraphic', 'tvBanner', 'wearScreenshots', 'tvScreenshots']
SHOTS = {'ko-KR': 'ko', 'en-US': 'en', 'ja-JP': 'ja', 'zh-CN': 'zh', 'zh-TW': 'zh-Hant', 'zh-HK': 'zh-Hant', 'es-ES': 'es', 'es-419': 'es', 'vi': 'vi'}
def ok(r, what):
    if r.status_code >= 300: raise SystemExit(f'[실패] {what}: {r.status_code} {r.text[:600]}')
    print('[완료]', what); return r.json() if r.text else {}
def counts(s, b):
    out = {}
    for l in s.get(f'{b}/listings').json().get('listings', []):
        lang = l['language']; out[lang] = {}
        for t in TYPES:
            n = len(s.get(f'{b}/listings/{lang}/{t}').json().get('images', []))
            if n: out[lang][t] = n
    return out
def show():
    s = session(); e = ok(s.post(f'{API}/edits'), '편집 열기(읽기용)')['id']; b = f'{API}/edits/{e}'
    try:
        for k, v in counts(s, b).items(): print(k, v)
    finally: s.delete(b)
def push(validate):
    s = session(); e = ok(s.post(f'{API}/edits'), '편집 열기')['id']; b = f'{API}/edits/{e}'; done = False
    try:
        before = counts(s, b)
        for lang, have in before.items():
            # 아이콘·피처 그래픽: 그 언어에 따로 있던 것만 바꾼다(없으면 기본 언어 것을 씀). 기본 언어 ko-KR 은 늘 바꾼다.
            for t, fn in (('icon', 'icon_512.png'), ('featureGraphic', 'feature_1024x500.png')):
                if lang == 'ko-KR' or have.get(t):
                    ok(s.delete(f'{b}/listings/{lang}/{t}'), f'{lang} {t} 지우기')
                    ok(s.post(f'{UP}/edits/{e}/listings/{lang}/{t}?uploadType=media', data=open(os.path.join(HERE, 'play-graphics', fn), 'rb').read(), headers={'Content-Type': 'image/png'}), f'{lang} {t}')
            for t in ('phoneScreenshots', 'sevenInchScreenshots', 'tenInchScreenshots'):
                if t != 'phoneScreenshots' and not have.get(t): continue
                ok(s.delete(f'{b}/listings/{lang}/{t}'), f'{lang} {t} 지우기')
                for fn in sorted(glob.glob(os.path.join(HERE, 'play-phone', lang, '*.jpg'))):
                    ok(s.post(f'{UP}/edits/{e}/listings/{lang}/{t}?uploadType=media', data=open(fn, 'rb').read(), headers={'Content-Type': 'image/jpeg'}), f'{lang} {t} {os.path.basename(fn)}')
        after = counts(s, b)
        for k in after: print('이후', k, after[k])
        if validate: ok(s.post(f'{b}:validate'), '검증')
        else: ok(s.post(f'{b}:commit'), '반영(commit)'); done = True
    finally:
        if not done: s.delete(b); print('[정리] 반영하지 않은 편집을 지움')
if __name__ == '__main__':
    show() if sys.argv[1] == 'show' else push('--validate' in sys.argv)
