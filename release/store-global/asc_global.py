"""App Store Connect 글로벌 등록정보(1.2.0) 넣기. 한국어(ko)는 건드리지 않는다.

  python asc_global.py meta        # 버전 1.2.0, 앱 정보·버전 로컬라이제이션, 아이폰 6.9" 스크린샷
  python asc_global.py show        # 다시 읽어 확인
키: %USERPROFILE%/keystores/appstore/asc.env (appstore-connect 스킬의 appstore.py ASC 클래스를 씀). 키 값은 출력하지 않는다.
"""
import hashlib, json, os, sys
from pathlib import Path

sys.path.insert(0, os.path.expanduser('~/.claude/skills/appstore-connect'))
import appstore  # noqa: E402
from appstore import ASC, rel  # noqa: E402

HERE = Path(__file__).resolve().parent
APP_ID = '6836670196'
VERSION = '1.2.0'
URL = 'https://childmbti.wonderwheel.co.kr/'
PRIVACY = 'https://childmbti.wonderwheel.co.kr/privacy.html'
DESC_FROM = {'en-US': 'en-US', 'ja': 'ja-JP', 'zh-Hans': 'zh-CN', 'es-ES': 'es-ES', 'es-MX': 'es-ES', 'vi': 'vi'}
L = json.loads((HERE / 'listings.json').read_text(encoding='utf-8'))


def locs(asc, path):
    return {x['attributes']['locale']: x for x in asc.get(path, limit=50)['data']}


def editable_version(asc):
    vs = asc.get(f'/apps/{APP_ID}/appStoreVersions', **{'filter[platform]': 'IOS', 'limit': 20})['data']
    for v in vs:
        if v['attributes']['versionString'] == VERSION:
            return v
    for v in vs:
        if v['attributes'].get('appStoreState') == 'PREPARE_FOR_SUBMISSION':
            print(f"편집 중 버전 {v['attributes']['versionString']} → {VERSION}")
            return asc.patch('appStoreVersions', v['id'], {'versionString': VERSION})['data']
    sys.exit('편집 중 버전이 없다')


def shots(asc, loc_id, folder):
    sets = {s['attributes']['screenshotDisplayType']: s
            for s in asc.get(f'/appStoreVersionLocalizations/{loc_id}/appScreenshotSets')['data']}
    s = sets.get('APP_IPHONE_67') or asc.create('appScreenshotSets', {'screenshotDisplayType': 'APP_IPHONE_67'},
                                                {'appStoreVersionLocalization': rel('appStoreVersionLocalizations', loc_id)})
    for old in asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots")['data']:
        asc.req('DELETE', f"/appScreenshots/{old['id']}")
    files = sorted(folder.glob('*.jpg'))
    for f in files:
        data = f.read_bytes()
        shot = asc.create('appScreenshots', {'fileName': f.name, 'fileSize': len(data)},
                          {'appScreenshotSet': rel('appScreenshotSets', s['id'])})
        for op in shot['attributes']['uploadOperations']:
            part = data[op['offset']:op['offset'] + op['length']]
            h = {x['name']: x['value'] for x in op.get('requestHeaders', [])}
            asc.http.request(op['method'], op['url'], data=part, headers=h).raise_for_status()
        asc.patch('appScreenshots', shot['id'], {'uploaded': True, 'sourceFileChecksum': hashlib.md5(data).hexdigest()})
    return len(files)


def meta():
    asc, errs = ASC(), []
    infos = asc.get(f'/apps/{APP_ID}/appInfos')['data']
    info = next((i for i in infos if i['attributes'].get('appStoreState') not in
                 ('READY_FOR_DISTRIBUTION', 'READY_FOR_SALE', 'REPLACED_WITH_NEW_INFO')), infos[0])
    il = locs(asc, f"/appInfos/{info['id']}/appInfoLocalizations")
    for loc, a in L['appstore'].items():
        attrs = {'name': a['name'], 'subtitle': a['subtitle'], 'privacyPolicyUrl': PRIVACY}
        try:
            if loc in il:
                asc.patch('appInfoLocalizations', il[loc]['id'], attrs)
            else:
                asc.create('appInfoLocalizations', {'locale': loc, **attrs}, {'appInfo': rel('appInfos', info['id'])})
            print('앱 정보', loc, 'OK')
        except RuntimeError as e:
            errs.append(f'앱 정보 {loc}: {e}'); print('[실패]', errs[-1])
    ver = editable_version(asc)
    vid = ver['id']
    vl = locs(asc, f'/appStoreVersions/{vid}/appStoreVersionLocalizations')
    for loc, a in L['appstore'].items():
        attrs = {'description': L['play'][DESC_FROM[loc]]['fullDescription'], 'keywords': a['keywords'],
                 'promotionalText': a['promotionalText'], 'supportUrl': URL, 'marketingUrl': URL}
        try:
            if loc in vl:
                asc.patch('appStoreVersionLocalizations', vl[loc]['id'], attrs)
            else:
                vl[loc] = asc.create('appStoreVersionLocalizations', {'locale': loc, **attrs},
                                     {'appStoreVersion': rel('appStoreVersions', vid)})
            n = shots(asc, vl[loc]['id'], HERE / 'iphone-6.9' / loc)
            print('버전', loc, 'OK, 스크린샷', n)
        except RuntimeError as e:
            errs.append(f'버전 {loc}: {e}'); print('[실패]', errs[-1])
    print('오류:', errs or '없음')


def show():
    asc = ASC()
    infos = asc.get(f'/apps/{APP_ID}/appInfos')['data']
    for i in infos:
        print('appInfo', i['id'], i['attributes'].get('appStoreState'))
        for loc, x in locs(asc, f"/appInfos/{i['id']}/appInfoLocalizations").items():
            a = x['attributes']; print(' ', loc, '|', a.get('name'), '|', a.get('subtitle'), '|', a.get('privacyPolicyUrl'))
    for v in asc.get(f'/apps/{APP_ID}/appStoreVersions', **{'filter[platform]': 'IOS'})['data']:
        b = asc.req('GET', f"/appStoreVersions/{v['id']}/build", ok404=True)
        bd = (b or {}).get('data') or {}
        print('version', v['attributes']['versionString'], v['attributes'].get('appStoreState'),
              'build', (bd.get('attributes') or {}).get('version'))
        for loc, x in locs(asc, f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations").items():
            a = x['attributes']
            ss = asc.get(f"/appStoreVersionLocalizations/{x['id']}/appScreenshotSets")['data']
            cnt = {s['attributes']['screenshotDisplayType']:
                   [y['attributes']['assetDeliveryState']['state'] for y in
                    asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots")['data']] for s in ss}
            print(' ', loc, 'desc', len(a.get('description') or ''), 'kw', len(a.get('keywords') or ''),
                  'promo', len(a.get('promotionalText') or ''), a.get('supportUrl'), {k: (len(v), set(v)) for k, v in cnt.items()})


NOTES_FROM = {'ko': 'ko-KR', 'en-US': 'en-US', 'ja': 'ja-JP', 'zh-Hans': 'zh-CN', 'es-ES': 'es-ES', 'es-MX': 'es-419', 'vi': 'vi'}


def builds(asc):
    return asc.get('/builds', **{'filter[app]': APP_ID, 'filter[preReleaseVersion.version]': VERSION,
                                 'sort': '-uploadedDate', 'limit': 5})['data']


def beta():
    """VALID 인 1.2.0 빌드를 버전에 붙이고, 외부 그룹 '외부 테스트'에 넣고, 테스트할 것(언어별)·베타 심사 제출."""
    asc = ASC()
    bs = [b for b in builds(asc) if b['attributes']['processingState'] == 'VALID']
    if not bs:
        sys.exit('VALID 인 1.2.0 빌드가 아직 없다: ' + str([(b['attributes']['version'], b['attributes']['processingState']) for b in builds(asc)]))
    b = bs[0]; bid = b['id']
    print('빌드', VERSION, b['attributes']['version'])
    ver = editable_version(asc)
    asc.req('PATCH', f"/appStoreVersions/{ver['id']}/relationships/build", {'data': {'type': 'builds', 'id': bid}})
    print('버전 1.2.0 에 빌드 연결')
    # 수출 규정(Info.plist 에 있으면 이미 false)
    if b['attributes'].get('usesNonExemptEncryption') is None:
        asc.patch('builds', bid, {'usesNonExemptEncryption': False})
    # 베타 앱 설명(언어별): 없는 언어만 더한다
    bal = {x['attributes']['locale']: x for x in asc.get(f'/apps/{APP_ID}/betaAppLocalizations', limit=50)['data']}
    for loc, a in L['appstore'].items():
        if loc not in bal:
            asc.create('betaAppLocalizations', {'locale': loc, 'description': a['promotionalText'],
                                                'feedbackEmail': 'contact@wonderwheel.co.kr', 'privacyPolicyUrl': PRIVACY,
                                                'marketingUrl': URL}, {'app': rel('apps', APP_ID)})
            print('베타 앱 설명', loc)
    # 테스트할 것(언어별)
    bbl = {x['attributes']['locale']: x for x in asc.get(f'/builds/{bid}/betaBuildLocalizations', limit=50)['data']}
    for loc, src in NOTES_FROM.items():
        txt = L['releaseNotes'][src]
        try:
            if loc in bbl:
                asc.patch('betaBuildLocalizations', bbl[loc]['id'], {'whatsNew': txt})
            else:
                asc.create('betaBuildLocalizations', {'locale': loc, 'whatsNew': txt}, {'build': rel('builds', bid)})
            print('테스트할 것', loc)
        except RuntimeError as e:
            print('[실패] 테스트할 것', loc, e)
    groups = {g['attributes']['name']: g for g in asc.get(f'/apps/{APP_ID}/betaGroups', limit=50)['data']}
    g = groups['외부 테스트']
    asc.req('POST', f"/betaGroups/{g['id']}/relationships/builds", {'data': [{'type': 'builds', 'id': bid}]})
    print("외부 그룹 '외부 테스트' 에 빌드 추가")
    try:
        asc.create('betaAppReviewSubmissions', {}, {'build': rel('builds', bid)})
        print('베타 심사 제출')
    except RuntimeError as e:
        print('[베타 심사]', e)
    st = asc.get(f'/builds/{bid}/betaAppReviewSubmission')
    print('베타 심사 상태:', ((st or {}).get('data') or {}).get('attributes'))


def status():
    asc = ASC()
    for b in builds(asc):
        a = b['attributes']
        sub = asc.req('GET', f"/builds/{b['id']}/betaAppReviewSubmission", ok404=True)
        print(VERSION, a['version'], a['processingState'], ((sub or {}).get('data') or {}).get('attributes'))


if __name__ == '__main__':
    {'meta': meta, 'show': show, 'beta': beta, 'status': status}[sys.argv[1]]()
