# iOS 출시 (App Store · TestFlight)

- 최종 수정일: 2026-11-19
- 버전: 1.0.1 (pubspec `1.0.1+2`)

## 지금 상태

| 항목 | 값 |
|---|---|
| Apple 팀 | 원더휠 주식회사 (팀 키, `%USERPROFILE%\keystores\appstore\`) |
| 번들 ID | `kr.co.wonderwheel.childmbti` (2026-11-19 API 로 등록, 이름 ChildMBTI) |
| 배포 프로파일 | `ChildMBTI App Store` (2026-11-19, 팀 배포 인증서 `wonderwheel_distribution`) |
| ASC 앱 | '내 아이의 MBTI', Apple ID 6836670196, SKU `childmbti`, 기본 언어 한국어 (2026-11-19 크롬으로 만듦) |
| 빌드 | Codemagic 워크플로 `ios-testflight` (저장소 루트 `codemagic.yaml`, `working_directory: app`) |
| 최소 iOS | 15.0 (`project.pbxproj`) |
| TestFlight | 1.0.1 빌드 1 VALID (Codemagic 첫 빌드, 커밋 ef15f44). 내부 테스트 그룹 '내부 테스트'(모든 빌드 자동)에 원더 계정 |

## 빌드 방법

- Windows 에서는 iOS 빌드를 못 하므로 Codemagic 의 Mac(`mac_mini_m2`)에서 한다. 푸시로 자동 시작하지 않고, Codemagic 화면의 Start new build 로 시작한다.
- 서명·업로드는 Codemagic Integrations 의 팀 API 키 `Codemagic` 로 한다. 이 저장소에는 비밀값이 없다(공개 저장소).
- 표시 버전은 pubspec 의 `+` 앞, 빌드 번호는 Codemagic `$BUILD_NUMBER`.
- Firebase iOS SDK 새 버전이 CocoaPods 에 없어 Swift Package Manager 를 켠다(`flutter config --enable-swift-package-manager`).
- `Info.plist` 에 `ITSAppUsesNonExemptEncryption=false` (표준 HTTPS 만 씀).
- `.github/workflows/ios.yml` 은 서명 없는 빌드 확인만 한다(GitHub 맥 러너).
- 결제는 아직 시제품이라 iOS 빌드도 결제 없이 열린다. 그래서 정식 심사 제출은 하지 않고 TestFlight 까지만 한다(애플은 인앱결제 연결이 필요).
- 계정(Firebase 로그인)은 iOS 에 `GoogleService-Info.plist` 가 없어 iOS 에서는 쓸 수 없다(`sync.dart` 가 초기화 실패를 잡아 계정 화면에 안내만 보인다). 또래 평균 통계는 REST 로 읽고 써서 iOS 에서도 된다.

## 남은 일

- 정식 심사 제출은 하지 않는다(결제가 시제품). 인앱결제를 붙이고 원더가 내라고 할 때 등록정보·스크린샷(`store/appstore/`, appstore-connect 스킬)과 함께 낸다.
- 외부 테스터(원더 개인 메일 등)는 외부 그룹 + 베타 심사가 필요하다(스킬 9번).
- iOS 계정 기능을 쓰려면 Firebase 에 iOS 앱을 만들고 `GoogleService-Info.plist` 를 넣는다.
