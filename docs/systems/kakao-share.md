# 카카오톡 공유

## 지금(2026-11-18)
- **앱**: 카카오톡 버튼은 공유 창을 거치지 않고 카카오톡의 친구·채팅 고르기 화면을 바로 연다.
  안드로이드 `Intent.ACTION_SEND` + `setPackage("com.kakao.talk")` (MainActivity.kt, 채널 `childmbti/share`).
  카카오 앱 키가 필요 없다. 카카오톡이 없으면 휴대폰 공유 창으로 대신한다(`doKakao`, app/lib/ui/links.dart).
  보내지는 것은 글+링크이고, 카카오톡이 링크 미리보기(og 태그 그림)를 붙인다.
  안드로이드 11 이상에서 설치 여부를 보려면 AndroidManifest `<queries><package android:name="com.kakao.talk"/>` 필요.
- **웹**: `SHARE.kakaoKey`(index.html) 가 비어 있어 휴대폰 공유 창 → 링크 복사로 대신한다.

## 카드형 공유(그림·버튼 달린 카카오 카드)로 바꾸려면 원더가 할 일
카카오 개발자 콘솔(developers.kakao.com) → 내 애플리케이션 → 앱 하나 만들기(이름 "내 아이의 MBTI").
1. 앱 키: **JavaScript 키**(웹), **네이티브 앱 키**(앱)를 전달.
2. 플랫폼 → Web → 사이트 도메인 `https://childmbti.wonderwheel.co.kr` 등록.
3. 플랫폼 → Android → 패키지 이름 `kr.co.wonderwheel.childmbti`, 키 해시 세 개 등록:
   - 플레이 앱 서명 키: Play Console → 앱 무결성 → 앱 서명 → "앱 서명 키 인증서" SHA-1 을 base64 로 바꾼 값
     (`echo <SHA1 콜론 포함> | xxd -r -p | base64`). **공개 테스트로 받은 앱은 이 키로 서명됨**.
   - 업로드 키, 디버그 키(`keytool -exportcert -alias <별칭> -keystore <파일> | openssl sha1 -binary | openssl base64`).
키를 받으면: 웹은 `SHARE.kakaoKey` 한 곳, 앱은 `kakao_flutter_sdk_share` 를 붙여 `doKakao` 를 카드 공유로 바꾼다.
