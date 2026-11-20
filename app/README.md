# 내 아이의 MBTI · 플루터 앱

웹 시제품(저장소 루트 `index.html`)을 그대로 옮긴 안드로이드용 플루터 앱입니다.
화면·문항·채점·링크 형식이 웹과 같아서, 웹에서 보낸 초대·결과 링크와 기록 파일을 앱에서도 읽습니다.

## 실행 (Flutter 3.41 이상, 원더 PC는 3.41.2)

```
cd app
flutter pub get
flutter run              # 연결한 안드로이드 폰이나 에뮬레이터
flutter test             # 채점·링크가 웹과 같은지, 화면 흐름 테스트
flutter build appbundle  # 플레이 등록용 AAB (서명 키는 PC에만, 저장소에 넣지 않음)
```

## 구조

| 파일 | 내용 |
|---|---|
| `assets/data/content.json` | 4축·자라는 힘·유형 설명·66문항 (웹에서 추출) |
| `lib/scoring.dart` | 채점, 양육자 비교, 재검사 비교 (웹과 같은 수치) |
| `lib/ads.dart` | AdMob 광고 ID 한곳, 보상형(검사 열기)·배너·앱 오프닝(3분 간격). 설명 `docs/systems/ads.md` |
| `lib/store.dart` | 아이·기록·구매 저장, 링크 만들기/읽기, 기록 파일 |
| `lib/ui/` | 홈·아이 등록·결제·검사·리포트·함께·더보기·받은 링크 화면, 손그림 9-slice 부품(`kit.dart`) |

## 화면 원칙 (2026-11-19 UX 개편)

- 화면마다 스크롤 없이 한 화면: `Frame`(위 줄 · 가운데 · 아래에 붙는 버튼)과 `Fit`(작은 폰·큰 글씨에서만 그 칸 안에서 밀림).
- 아래 메뉴 3개: 홈 · 리포트 · 더보기(함께 보기: 가족 초대·공유 / 계정·가격·기록 지우기 / 만든 사람). 개인정보처리방침 링크는 결제·계정 화면에 있다.
- 흐름: 처음 → 아이 등록 2단계(`setup.dart`, 나이는 태어난 해와 달로 받아 만 나이를 계산) → 보상형 광고 → 한 문항씩 검사 → 리포트.
- 리포트는 탭마다 요약 한 장에서 강조된 '자세히 보기'(`MoreBtn`)로 들어가고 '이전'으로 돌아온다(`Drill`). 화면 깊이는 요약 → 상세 한 단계까지만. 그보다 깊은 설명·읽는 법·고르기·보내기·입력은 모두 가운데 팝업창(`popup`). 아래에서 올라오는 창은 쓰지 않는다.
- 새 화면을 만들 때 `ListView`로 길게 쌓지 말고 이 틀을 쓴다. `flutter test`가 360x640에서 넘침을 확인한다.

## 아직 안 된 것 (2단계)

- (2026-11-20) 결제 대신 광고: 검사는 보상형 광고 1번으로 열림. `docs/systems/ads.md`.
- Firebase 메일 인증 동기화, 앱 안 계정 삭제 + 웹 삭제 요청 주소, 심사용 로그인 계정.
- 카카오 SDK 공유(지금은 휴대폰 공유 창), 앱 링크(도메인에 assetlinks.json).
- 패키지 이름 `kr.co.wonderwheel.childmbti`는 임시. 원더의 앱 패키지 규칙이 정해지면 바꿈.

## Firebase

- 프로젝트 `childmbti-wonderwheel` (원더휠 회사 구글 계정, 무료 Spark), 콘솔 https://console.firebase.google.com/project/childmbti-wonderwheel/overview
- 안드로이드 앱 등록됨, 설정 파일 `android/app/google-services.json` (앱에 들어가는 공개 설정이라 저장소에 둠).
- Firestore 서울(asia-northeast3), 보안 규칙은 아직 기본값(모두 막힘). 이메일 로그인(비밀번호·메일 링크) 켜짐.
- 패키지 이름을 바꾸면 Firebase에 앱을 다시 등록하고 이 파일을 새로 받아야 함.
- 로그인·동기화: `lib/sync.dart`, 계정 화면 `lib/ui/account.dart`. 설명 `docs/systems/account-sync.md`.

## 또래 평균 통계
지표 옆 아이콘을 누르면 같은 만 나이·성별 아이들의 평균을 보여 준다(5건 이상 모였을 때). 자료 구조와 규칙은 [docs/systems/stats.md](../docs/systems/stats.md), 코드는 `lib/stats.dart`. 서버 규칙 `firestore.rules` 를 고치면 `firebase deploy --only firestore:rules` 로 배포해야 한다.

## 인트로
앱을 켜면 원더휠 스플래시(흰 바탕, `assets/img/wonderwheel.png`, 1.8초) → 타이틀 화면(버튼 없이 화면을 터치하면 시작) → 홈. 코드는 `lib/ui/intro.dart`, 지났는지는 `introDone`.
