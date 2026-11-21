# 글로벌 출시 1.2.0 (2026-11-21)

원더 요청: "모든 언어를 적용하면 번역 qa풀테스트를 진행해줘. 그리고 구글플레이 앱스토어에도 글로벌 세팅 하고 배포까지 진행해줘"

- 앱: 6개 언어(ko·en·ja·zh·es·vi), 버전 1.2.0+5 (main).
- `listings.json`: 언어별 스토어 문구. **한국어 등록정보는 지금 스토어 값을 그대로 둔다(손대지 않음).**
  - `play.<언어>`: 구글 플레이 title / shortDescription / fullDescription. `es-419` 는 `es-ES` 와 같은 문구.
  - `appstore.<언어>`: name / subtitle / keywords / promotionalText. description 은 같은 언어의 play fullDescription (en-US←en-US, ja←ja-JP, zh-Hans←zh-CN, es-ES·es-MX←es-ES, vi←vi).
  - `releaseNotes.<언어>`: 출시 노트(플레이 언어 코드).
- 스크린샷(JPEG):
  - `play-phone/<플레이 언어>/1..5.jpg` 1080x1920 → 그 언어 phoneScreenshots
  - `iphone-6.9/<ASC 언어>/1..6.jpg` 1290x2796 → APP_IPHONE_67. 아이패드는 기본(한국어) 스크린샷을 쓰도록 둔다.

## 할 일
1. 구글 플레이 (gcloud 대리 인증 `~/.claude/tools/play/play_auth.py`, JSON 키 없음)
   - AAB 1.2.0+5 빌드(업로드 키 `%USERPROFILE%\keystores\childmbti\`) → 공개 테스트(beta) 트랙 새 출시, 출시 노트 위 언어별, 전체 출시.
   - 공개 테스트 국가: 대한민국만 → 사용 가능한 모든 국가로(API 로 안 되면 콘솔/크롬).
   - 등록정보 en-US, ja-JP, zh-CN, es-ES, es-419, vi 추가 + 언어별 휴대폰 스크린샷. ko-KR 은 건드리지 않음.
   - 프로덕션 트랙은 건드리지 않음.
2. 앱스토어 (`~/.claude/skills/appstore-connect`, 키 `%USERPROFILE%\keystores\appstore`, 키 값 출력 금지)
   - Codemagic `ios-testflight` 로 1.2.0 빌드 → VALID 확인 → 외부 그룹 '외부 테스트'(kilius@naver.com) 추가 + 베타 심사 제출, What to Test 언어별.
   - 편집 중인 앱스토어 버전(1.1.0, PREPARE_FOR_SUBMISSION)을 1.2.0 으로 바꾸고 새 빌드 연결.
   - appInfoLocalizations(name, subtitle, privacyPolicyUrl https://childmbti.wonderwheel.co.kr/privacy.html) 와 appStoreVersionLocalizations(description, keywords, promotionalText, supportUrl·marketingUrl https://childmbti.wonderwheel.co.kr/, whatsNew 는 첫 버전이라 생략) 를 en-US, ja, zh-Hans, es-ES, es-MX, vi 로 추가 + 아이폰 6.9" 스크린샷.
   - **심사 제출(Submit for Review)은 하지 않는다.**
