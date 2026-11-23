"""TestFlight 외부 테스트로 빌드 보내기 (앱스토어 편집 중 버전에는 손대지 않음).

  python testflight_external.py <버전> <빌드번호> [--wait]
빌드가 VALID 가 될 때까지 기다린 뒤(--wait), 직전 외부 빌드의 '테스트할 것'(언어별)을 복사해 넣고,
외부 그룹 '외부 테스트'에 추가하고 베타 심사를 제출한다. 키: %USERPROFILE%/keystores/appstore/asc.env
"""
import os, sys, time

sys.path.insert(0, os.path.expanduser('~/.claude/skills/appstore-connect'))
from appstore import ASC, rel  # noqa: E402

APP_ID = '6836670196'


def find(asc, ver, num):
    for b in asc.get('/builds', **{'filter[app]': APP_ID, 'filter[preReleaseVersion.version]': ver,
                                   'filter[version]': num, 'limit': 5})['data']:
        return b


def main():
    ver, num = sys.argv[1], sys.argv[2]
    asc = ASC()
    for i in range(80):
        b = find(asc, ver, num)
        st = b and b['attributes']['processingState']
        if st == 'VALID' or '--wait' not in sys.argv:
            break
        print('대기', i, st, flush=True)
        time.sleep(60)
    if not b or b['attributes']['processingState'] != 'VALID':
        sys.exit(f'{ver} ({num}) 이 VALID 가 아님: {st}')
    bid = b['id']
    if b['attributes'].get('usesNonExemptEncryption') is None:
        asc.patch('builds', bid, {'usesNonExemptEncryption': False})
    groups = {g['attributes']['name']: g for g in asc.get(f'/apps/{APP_ID}/betaGroups', limit=50)['data']}
    g = groups['외부 테스트']
    # 직전 외부 빌드의 '테스트할 것'을 복사(없는 언어만)
    prev = asc.get(f"/betaGroups/{g['id']}/builds", limit=5)['data']
    src = {}
    for p in prev:
        src = {x['attributes']['locale']: x['attributes'].get('whatsNew') for x in
               asc.get(f"/builds/{p['id']}/betaBuildLocalizations", limit=50)['data'] if x['attributes'].get('whatsNew')}
        if src:
            print('테스트할 것 복사 원본: 빌드', p['attributes']['version'])
            break
    have = {x['attributes']['locale']: x for x in asc.get(f'/builds/{bid}/betaBuildLocalizations', limit=50)['data']}
    for loc, txt in src.items():
        if loc in have and have[loc]['attributes'].get('whatsNew'):
            continue
        if loc in have:
            asc.patch('betaBuildLocalizations', have[loc]['id'], {'whatsNew': txt})
        else:
            asc.create('betaBuildLocalizations', {'locale': loc, 'whatsNew': txt}, {'build': rel('builds', bid)})
    print('테스트할 것 언어:', sorted(src))
    asc.req('POST', f"/betaGroups/{g['id']}/relationships/builds", {'data': [{'type': 'builds', 'id': bid}]})
    print("외부 그룹 '외부 테스트' 에 추가")
    try:
        asc.create('betaAppReviewSubmissions', {}, {'build': rel('builds', bid)})
        print('베타 심사 제출')
    except RuntimeError as e:
        print('[베타 심사]', e)
    s = asc.req('GET', f'/builds/{bid}/betaAppReviewSubmission', ok404=True)
    print('상태:', ((s or {}).get('data') or {}).get('attributes'))


if __name__ == '__main__':
    main()
