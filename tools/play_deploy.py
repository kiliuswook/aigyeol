"""구글 플레이 배포(키 파일 없음). 설명: docs/systems/play-deploy.md

인증
- GitHub Actions: google-github-actions/auth 가 Workload Identity Federation 으로 만든 자격 증명(ADC)을 쓴다.
  play-publisher 서비스 계정을 대리하고, 사람 로그인·재인증과 상관없다.
- PC: ~/.claude/tools/play/play_auth.py (gcloud 로그인이 서비스 계정을 대리).

  python tools/play_deploy.py check                        # 트랙 상태만 읽기
  python tools/play_deploy.py upload <aab> [--track beta] [--notes release/store-global/listings.json] [--validate]
"""
import argparse, json, os, sys

PKG = 'kr.co.wonderwheel.childmbti'
API = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}'
UP = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}'


def session():
    if os.environ.get('GITHUB_ACTIONS') or os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'):
        import google.auth
        from google.auth.transport.requests import AuthorizedSession
        cred, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/androidpublisher'])
        return AuthorizedSession(cred)
    sys.path.insert(0, os.path.expanduser('~/.claude/tools/play'))
    from play_auth import session as s
    return s()


def ok(r, what):
    if r.status_code >= 300:
        raise SystemExit(f'[실패] {what}: {r.status_code} {r.text[:800]}')
    print('[완료]', what)
    return r.json() if r.text else {}


def notes_from(path):
    if not path:
        return []
    d = json.load(open(path, encoding='utf-8'))
    d = d.get('releaseNotes', d)
    return [{'language': k, 'text': v} for k, v in d.items() if not k.startswith('_')]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['check', 'upload'])
    ap.add_argument('aab', nargs='?')
    ap.add_argument('--track', default='beta')
    ap.add_argument('--notes', default='')
    ap.add_argument('--name', default='')
    ap.add_argument('--validate', action='store_true', help='검증만 하고 편집을 버린다')
    a = ap.parse_args()
    s = session()
    e = ok(s.post(f'{API}/edits'), '편집 열기')['id']
    b = f'{API}/edits/{e}'
    done = False
    try:
        if a.cmd == 'check':
            for t in s.get(f'{b}/tracks').json().get('tracks', []):
                print('track', t['track'], [(r.get('name'), r.get('versionCodes'), r.get('status')) for r in t.get('releases', [])])
            return
        with open(a.aab, 'rb') as f:
            vc = ok(s.post(f'{UP}/edits/{e}/bundles?uploadType=media', data=f.read(),
                           headers={'Content-Type': 'application/octet-stream'}, timeout=1800), 'AAB 올리기')['versionCode']
        rel = {'versionCodes': [str(vc)], 'status': 'completed'}
        if a.name:
            rel['name'] = a.name
        n = notes_from(a.notes)
        if n:
            rel['releaseNotes'] = n
        ok(s.put(f'{b}/tracks/{a.track}', json={'track': a.track, 'releases': [rel]}), f'{a.track} 트랙 versionCode {vc}')
        if a.validate:
            ok(s.post(f'{b}:validate'), '검증')
        else:
            ok(s.post(f'{b}:commit'), '반영(commit) — 검토로 전송됨')
            done = True
    finally:
        if not done:
            s.delete(b)
            print('[정리] 반영하지 않은 편집을 지움')


if __name__ == '__main__':
    main()
