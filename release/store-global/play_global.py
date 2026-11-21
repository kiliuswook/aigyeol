"""구글 플레이 글로벌 1.2.0: AAB 를 공개 테스트(beta)에 내고, 6개 언어 등록정보·휴대폰 스크린샷을 넣는다.
ko-KR 등록정보와 프로덕션 트랙은 건드리지 않는다. 인증은 ~/.claude/tools/play/play_auth.py (gcloud 대리, 키 파일 없음).

  python play_global.py show
  python play_global.py push <aab> [--validate]   # --validate 면 검증만 하고 편집을 버린다
"""
import glob, json, os, sys

sys.path.insert(0, os.path.expanduser('~/.claude/tools/play'))
from play_auth import session  # noqa: E402

PKG = 'kr.co.wonderwheel.childmbti'
API = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}'
UP = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}'
HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, 'listings.json'), encoding='utf-8'))
LANGS = ['en-US', 'ja-JP', 'zh-CN', 'es-ES', 'es-419', 'vi']


def ok(r, what):
    if r.status_code >= 300:
        raise SystemExit(f'[실패] {what}: {r.status_code} {r.text[:800]}')
    print('[완료]', what)
    return r.json() if r.text else {}


def show():
    s = session()
    e = ok(s.post(f'{API}/edits'), '편집 열기(읽기용)')['id']
    b = f'{API}/edits/{e}'
    try:
        for t in s.get(f'{b}/tracks').json().get('tracks', []):
            print('track', t['track'], [(r.get('name'), r.get('versionCodes'), r.get('status'),
                                         [n['language'] for n in r.get('releaseNotes', [])]) for r in t.get('releases', [])])
        for tr in ('beta', 'production'):
            r = s.get(f'{b}/countryAvailability/{tr}')
            j = r.json() if r.ok and r.text.strip() else f'{r.status_code} {r.text[:200]}'
            if isinstance(j, dict):
                print('countries', tr, 'restOfWorld=', j.get('restOfWorld'), len(j.get('countries', [])), 'countries')
            else:
                print('countries', tr, j)
        for l in s.get(f'{b}/listings').json().get('listings', []):
            n = len(s.get(f"{b}/listings/{l['language']}/phoneScreenshots").json().get('images', []))
            print('listing', l['language'], '|', l.get('title'), '| short', len(l.get('shortDescription', '')),
                  '| full', len(l.get('fullDescription', '')), '| phone shots', n)
    finally:
        s.delete(b)


def push(aab, validate):
    for lang in LANGS:
        p = L['play'].get(lang) or L['play'][L['play_copy'][lang]]
        assert len(p['title']) <= 30 and len(p['shortDescription']) <= 80 and len(p['fullDescription']) <= 4000, lang
        assert len(L['releaseNotes'][lang]) <= 500, lang
    s = session()
    e = ok(s.post(f'{API}/edits'), '편집 열기')['id']
    b = f'{API}/edits/{e}'
    done = False
    try:
        with open(aab, 'rb') as f:
            vc = ok(s.post(f'{UP}/edits/{e}/bundles?uploadType=media', data=f.read(),
                           headers={'Content-Type': 'application/octet-stream'}, timeout=1800), 'AAB 올리기')['versionCode']
        notes = [{'language': k, 'text': v} for k, v in L['releaseNotes'].items()]
        ok(s.put(f'{b}/tracks/beta', json={'track': 'beta', 'releases': [
            {'name': f'1.2.0 ({vc})', 'versionCodes': [str(vc)], 'status': 'completed', 'releaseNotes': notes}]}),
           f'공개 테스트(beta) 출시 versionCode {vc}')
        for lang in LANGS:
            p = L['play'].get(lang) or L['play'][L['play_copy'][lang]]
            ok(s.put(f'{b}/listings/{lang}', json={'language': lang, **p}), f'등록정보 {lang}')
            ok(s.delete(f'{b}/listings/{lang}/phoneScreenshots'), f'{lang} 기존 휴대폰 스크린샷 지우기')
            for fn in sorted(glob.glob(os.path.join(HERE, 'play-phone', lang, '*.jpg'))):
                with open(fn, 'rb') as fh:
                    ok(s.post(f'{UP}/edits/{e}/listings/{lang}/phoneScreenshots?uploadType=media', data=fh.read(),
                              headers={'Content-Type': 'image/jpeg'}), f'{lang} 스크린샷 {os.path.basename(fn)}')
        if validate:
            ok(s.post(f'{b}:validate'), '검증')
        else:
            ok(s.post(f'{b}:commit'), '반영(commit)')
            done = True
    finally:
        if not done:
            s.delete(b); print('[정리] 반영하지 않은 편집을 지움')


if __name__ == '__main__':
    if sys.argv[1] == 'show':
        show()
    else:
        push(sys.argv[2], '--validate' in sys.argv)
