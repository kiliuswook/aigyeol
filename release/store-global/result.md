# 글로벌 출시 1.2.0 결과 (2026-11-21)

작업: 원더 PC. 아래 값은 모두 반영한 뒤 API·콘솔에서 다시 읽어 확인한 실제 상태다.
출시 빌드는 **1.2.0+6** 이다(처음 계획한 +5 에 스토어 업데이트 알림·평가 권유 e4b3068 을 더한 것, 빌드 고침 c90d5a5).
입력 도구: `asc_global.py`(앱스토어), `play_global.py`(플레이). 한국어 등록정보와 플레이 프로덕션 트랙은 건드리지 않았다.

## 구글 플레이 (kr.co.wonderwheel.childmbti)

| 항목 | 상태 |
|---|---|
| AAB | `app/build/app/outputs/bundle/release/childmbti-1.2.0+6.aab` (versionCode 6, 업로드 키 서명 확인) |
| 공개 테스트(beta) | 1.2.0 (6) 전체 출시(completed), 출시 노트 7개 언어(ko-KR, en-US, ja-JP, zh-CN, es-ES, es-419, vi). 1.1.0 (4) 를 대체. Google 검토 중 |
| 공개 테스트 국가 | 대한민국 1개 → 177개 국가 + 기타 국가(restOfWorld) (콘솔에서 저장 → 게시 개요에서 검토 제출) |
| 등록정보 | en-US, ja-JP, zh-CN, es-ES, es-419, vi 추가 (제목·간단한 설명·자세한 설명 = listings.json), 각 휴대폰 스크린샷 5장. ko-KR 그대로(스크린샷 6장) |
| 프로덕션 | 손대지 않음(출시 없음) |

- 콘솔 게시 개요에서 "검토 다시 시작" 으로 출시·국가·등록정보 변경을 한 번에 검토 받는 중(관리형 게시 꺼짐 → 승인되면 바로 공개).
- 새 언어 등록정보의 아이콘·그래픽 이미지는 따로 넣지 않아 기본 언어(ko-KR) 것을 쓴다.
- AAB 빌드 때 Flutter 가 "failed to strip debug symbols" 로 끝 코드 1 을 내지만 AAB 는 정상으로 만들어진다(1.1.0+4 때와 같음).

## 앱스토어 (Apple ID 6836670196)

| 항목 | 상태 |
|---|---|
| 빌드 | Codemagic `ios-testflight` #6 (커밋 c90d5a5) → 1.2.0 (6) VALID. (#5 = 1.2.0 (5), cce6640, 기능 빠진 빌드라 쓰지 않음) |
| 편집 중 버전 | 1.1.0 → **1.2.0** (PREPARE_FOR_SUBMISSION), 빌드 6 연결 |
| 앱 정보 로컬라이제이션 | en-US, ja, zh-Hans, es-ES, es-MX, vi: 이름·부제·개인정보처리방침 URL |
| 버전 로컬라이제이션 | 같은 6개: 설명(플레이 자세한 설명), 키워드, 홍보 문구, 지원·마케팅 URL. 새로운 기능은 첫 버전이라 생략 |
| 스크린샷 | 6개 언어 아이폰 6.9"(APP_IPHONE_67) 6장씩 COMPLETE. 아이패드는 한국어 것만(새 언어는 기본 언어 것을 씀) |
| 한국어 | 그대로(설명·키워드·스크린샷 8장·아이패드 5장) |
| TestFlight 외부 | 그룹 '외부 테스트'(kilius@naver.com)에 1.2.0 (6) 추가, 베타 앱 설명 6개 언어 추가, 테스트할 것 7개 언어, **베타 심사 제출 → WAITING_FOR_REVIEW** |
| 정식 심사 제출 | **하지 않음** |

## 실패·오류와 처리

- gcloud 재인증 만료("Reauthentication failed") → 원더가 터미널에서 비밀번호 입력 후 진행. 근본 해결 제안: 워크스페이스 관리 콘솔 > 보안 > Google Cloud 세션 제어에서 재인증 끄기(또는 주기 늘리기), 장기적으로 GitHub Actions + Workload Identity Federation.
- e4b3068 의 `in_app_update: ^5.0.0` 이 Dart 3.12 를 요구해 Flutter 3.41.2(PC·Codemagic)에서 pub get 실패 → `^4.2.5` 로 고침(c90d5a5).

## 원더가 할 일

1. 기다리기: 플레이 검토(보통 몇 시간~하루, 통과하면 공개 테스트가 모든 국가에 열림), TestFlight 베타 심사(보통 하루 안, 통과하면 kilius@naver.com 에 초대 메일).
2. 앱스토어 정식 심사를 낼 때(원더 결정): 앱 개인정보 보호 설문(광고 데이터 포함)·심사 연락처가 아직 비어 있으면 먼저 채운다(release/app-store/result.md 의 남은 일). 그 뒤 1.2.0 제출.
3. (선택) 새 언어용 아이패드 스크린샷·플레이 그래픽 이미지(언어별)가 필요하면 말해 주세요.
