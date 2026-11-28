# 공유 링크 · 가족 연결 · 결과 그림 공유

2026-11-21 원더 요청: "웹으로 연동하지 않고 바로 구글플레이, 앱스토어 링크를 연결 / 양육자 초대인 경우는 계정과 정보가 연동되도록 / 공유시 이미지를 캡쳐해서 공유".

## 1. 공유 링크는 스토어로 (go/)

앱의 공유 링크는 모두 `https://childmbti.wonderwheel.co.kr/go/#값` 이다(`kGo`, app/lib/store.dart). 웹 검사(index.html)로 보내지 않는다.
`go/index.html` 이 기기를 보고 바로 보낸다.

| 기기 | 동작 |
|---|---|
| 안드로이드 | `intent://open?값#Intent;scheme=childmbti;package=…;S.browser_fallback_url=플레이;end` 로 이동. 앱이 있으면 앱이 열리고, 없으면 구글 플레이(`&referrer=값`). |
| 아이폰 | 앱스토어(`IOS_STORE`). 초대는 초대 코드를 복사하고 앱스토어로. **`IOS_LIVE=false` 인 동안(출시 전)** 은 스토어가 열리지 않아 웹 검사·앱 열기만 안내한다. 출시 뒤 `IOS_LIVE=true`. |
| PC | 구글 플레이 버튼(+출시 뒤 앱스토어), 초대 코드, 웹 검사 |

값: `f=가족 연결 코드&w=역할`(초대), `t=유형`(결과 공유), `r=app`(앱 추천), `i=`·`c=`(예전 초대·결과 링크, 인터넷이 없어 코드를 못 만들 때).
문구는 6개 언어(브라우저 언어).

앱이 받는 곳: `childmbti://open?값` (AndroidManifest intent-filter, iOS CFBundleURLSchemes) → `app_links` → `Landing.parse` → `LandScreen` (app/lib/deeplink.dart).
플러터 기본 딥링크 경로 이동은 껐다(`flutter_deeplinking_enabled` / `FlutterDeepLinkingEnabled` false).

웹(index.html)도 결과 공유·앱 추천은 go/ 로(`SHARE.store`). 웹끼리 주고받는 초대·결과 링크는 웹 주소 그대로.

## 2. 가족 연결(공동 양육자 초대) — app/lib/fam.dart

초대할 때 서버(Firestore `fam/{코드}`)에 아이 정보와 이 휴대폰의 양육자 결과를 올리고 코드를 아이(`Kid.fam`)에 붙인다.
같은 코드를 가진 휴대폰끼리 그 아이의 양육자별 결과가 자동으로 오간다. 결과 링크를 다시 보낼 필요가 없다.

- 코드: 10자리, `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`(0·O·1·I 없음), 보일 때 `ABCDE-FGH23`. 로그인 없이 쓰고, 코드를 아는 사람만 그 문서를 읽고 고친다(규칙 `firestore.rules` 의 fam: get 만, list·delete 막음, 바꿀 수 있는 칸은 recs·이름·연령·생년월·성별).
- 문서: `{k 아이 key, n 이름, a 연령, b 생년월, s 성별, f 초대한 양육자, p 첫 검사 여부, at, recs: {양육자: {x 66문항 답, d 검사일, t 바뀐 때}}}`
- 올리기: 기록이 바뀌면 3초 뒤, 이 휴대폰에서 직접 답한 기록(받은 결과·샘플 제외)만 `recs.<양육자>` 로.
- 받기: 앱을 켤 때(Firebase 준비 뒤), 앱으로 돌아올 때, 리포트 탭을 열 때(20초에 한 번). 받은 기록은 `recv: true`. 이 휴대폰에서 직접 답한 같은 이름의 기록은 덮지 않는다.
- **초대받아 처음 검사하는 사람은 자기 검사를 다 마칠 때까지 다른 사람 결과를 받지 않는다**(서로의 답에 끌리지 않게, caregivers.md 원칙).
- 양육자 초대 창에 초대 코드와 **코드 복사** 버튼(2026-11-22): 창을 열면 코드를 바로 받아 와 보여 주고, 버튼을 누르면 `ABCDE-FGH23` 꼴로 복사한다.
- 인터넷이 없거나 Firebase 를 못 쓰면 예전 방식(아이 정보를 실은 `#i=` 링크 + 결과 링크 보내기)으로 대신한다.

설치를 거쳐도 초대가 이어지는 방법:
- 안드로이드: 플레이 설치 정보(Install Referrer, `MainActivity.kt` 의 `referrer`, 라이브러리 `com.android.installreferrer:installreferrer:2.2`). 설치 뒤 처음 켤 때 한 번 읽는다(`childmbti_ref_done`).
- 아이폰: 앱스토어는 설치 정보를 넘겨주지 않는다. 초대 문구와 go/ 페이지에 초대 코드가 있고, 앱의 **더보기 › 초대 코드 입력** 또는 처음 화면 **가족에게 초대받았어요** 에 넣는다(초대 문구 전체를 붙여 넣어도 코드를 찾음).

## 3. 결과 그림 공유

결과 공유 창(`shareResult`, app/lib/ui/share.dart)에 공유용 결과 카드(`ResultCard`: 유형 캐릭터·네 글자·별명·네 축 막대·앱 이름)가 보이고, 보이는 그대로 PNG 로 찍어(`capture`, 3배 해상도) 링크와 함께 보낸다.
- 아이 이름은 기본으로 빼고, '아이 이름 넣기'를 누르면 카드 제목에 넣는다. 답한 내용은 보내지 않는다.
- 카카오톡: 그림을 카카오 서버에 올려(`ShareClient.uploadImage`) 카드 그림으로 쓴다. 실패하면 기본 그림(assets/og_v2.png, 1.3.1 이전 앱 빌드는 assets/og.png — 두 파일 모두 새 캐릭터 그림).
- 다른 앱: 휴대폰 공유 창에 그림 파일 + 문구·링크.

## 원더 확인·할 일
- 아이폰 앱스토어 출시 뒤: `go/index.html` 의 `IOS_LIVE` 를 true 로, 카카오 콘솔 iOS 앱스토어 ID(6836670196) 입력.
- 새 기능은 새 빌드(1.2.1)부터 동작한다. 예전 빌드가 만든 초대 링크(`#i=`)는 웹으로 가던 것 그대로다.
