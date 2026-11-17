# 내 아이의 MBTI · 플루터 앱

웹 시제품(저장소 루트 `index.html`)을 그대로 옮긴 안드로이드용 플루터 앱입니다.
화면·문항·채점·링크 형식이 웹과 같아서, 웹에서 보낸 초대·결과 링크와 기록 파일을 앱에서도 읽습니다.

## 실행

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
| `lib/store.dart` | 가격 `Price` 한곳, 아이·기록·구매 저장, 링크 만들기/읽기, 기록 파일 |
| `lib/ui/` | 홈·결제·검사·리포트·공유·받은 링크 화면, 손그림 9-slice 부품(`kit.dart`) |

## 아직 안 된 것 (2단계)

- 실제 결제: 구글 플레이 결제(소모성 상품 `test_first` $1, `test_more` $0.50). 지금은 결제 버튼이 바로 열어 줌.
- Firebase 메일 인증 동기화, 앱 안 계정 삭제 + 웹 삭제 요청 주소, 심사용 로그인 계정.
- 카카오 SDK 공유(지금은 휴대폰 공유 창), 앱 링크(도메인에 assetlinks.json).
- 패키지 이름 `kr.co.wonderwheel.childmbti`는 임시. 원더의 앱 패키지 규칙이 정해지면 바꿈.

## Firebase

- 프로젝트 `childmbti-wonderwheel` (원더휠 회사 구글 계정, 무료 Spark), 콘솔 https://console.firebase.google.com/project/childmbti-wonderwheel/overview
- 안드로이드 앱 등록됨, 설정 파일 `android/app/google-services.json` (앱에 들어가는 공개 설정이라 저장소에 둠).
- Firestore 서울(asia-northeast3), 보안 규칙은 아직 기본값(모두 막힘). 이메일 로그인(비밀번호·메일 링크) 켜짐.
- 패키지 이름을 바꾸면 Firebase에 앱을 다시 등록하고 이 파일을 새로 받아야 함.
- 로그인·동기화: `lib/sync.dart`, 계정 화면 `lib/ui/account.dart`. 설명 `docs/systems/account-sync.md`.
