# 카카오톡 공유

카카오 개발자 콘솔 앱: **내 아이의 MBTI** (앱 ID 1656799, 원더휠 카카오 계정, 2026-11-19 생성)
- JavaScript 키 `7f384e7c7f27f5981b1e8dd43f5953ff` — JS SDK 도메인: https://childmbti.wonderwheel.co.kr, https://kiliuswook.github.io
- 네이티브 앱 키 `29136e8e9e21e8bbdab28bceee0dbd57` — Android 패키지 `kr.co.wonderwheel.childmbti`, 스토어 구글 플레이
  - 키 해시: 플레이 앱 서명 키 `gwOcCcuHt5D9QlNOaCycN5xLNWU=` (SHA-1 83:03:9C:…:35:65), 업로드 키 `AaWOYlfQP1+wBrFGEIlosOO0Dt4=` (SHA-1 01:A5:8E:…:0E:DE)
  - 디버그 키는 미등록 → `flutter run` 디버그 빌드에서는 카드 공유가 실패하고 아래 2)로 넘어간다. 필요하면 PC 디버그 키 해시를 추가.
- iOS 번들 ID `kr.co.wonderwheel.childmbti` — 같은 네이티브 앱 키에 2026-11-20 추가(그 전에는 빠져 있어 아이폰에서 카드 공유가 실패했다). 앱스토어 ID 는 비워 둠(아직 출시 전).
- 제품 링크 관리 → 웹 도메인: https://childmbti.wonderwheel.co.kr (카드 링크가 이 도메인이어야 함)
- 2026-11-20 콘솔 점검 결과: Android 패키지·스토어 URL·키 해시 두 개, JS SDK 도메인 두 개, 웹 도메인, 네이티브 앱 스킴(Android·iOS) 모두 위 값과 같다. 카카오톡 공유는 따로 켜는 설정이 없다.
- PC 웹에서 카카오톡 버튼을 누르면 카카오 로그인 창이 새로 뜨는 것이 정상이다(로그인 뒤 친구 고르기). 휴대폰 웹에서는 카카오톡 앱이 열린다.
두 키는 원래 앱·웹 코드에 실리는 공개 값이다(등록된 도메인·서명 키에서만 동작).

## 웹 (index.html)
`SHARE.kakaoKey` = JavaScript 키 → 카카오톡 버튼이 `Kakao.Share.sendDefault` 카드 공유. 실패하면 휴대폰 공유 창 → 링크 복사.

## 앱 (app/lib/ui/links.dart `doKakao`)
1. `kakao_flutter_sdk_share` 카드 공유(그림 assets/og.png, 제목·설명, 버튼). `main()`에서 `initKakao()`.
2. 실패하면 카카오톡에 글+링크로 바로 보내기: 안드로이드 `ACTION_SEND` + `setPackage("com.kakao.talk")` (MainActivity.kt, 채널 `childmbti/share`, 앱 키 불필요).
3. 카카오톡이 없으면 휴대폰 공유 창.
