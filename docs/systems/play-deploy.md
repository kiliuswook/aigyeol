# 구글 플레이 배포 (키 없는 자동 배포)

- 최종 수정일: 2026-11-21
- 버전: 앱 1.2.0 (pubspec `1.2.0+6`)
- 구현: `.github/workflows/play-deploy.yml`, `tools/play_deploy.py`

## 왜

PC 의 gcloud 로그인(contact@)이 서비스 계정 `play-publisher` 를 대리하는 방식은, 워크스페이스의 Google Cloud 세션 제어 때문에
몇 시간마다 비밀번호 재인증("Reauthentication failed")이 필요했다. GitHub Actions 는 Workload Identity Federation(WIF)으로
같은 서비스 계정을 대리하므로 사람 로그인·재인증·JSON 키가 필요 없다(조직 정책 "키 생성 금지"와도 맞음).

## 설정 (2026-11-21, GCP 프로젝트 `key-hope-514901-c5`, 번호 352867707269)

| 항목 | 값 |
|---|---|
| Workload Identity 풀 | `github` (global) |
| 공급자 | `github-actions`, OIDC `https://token.actions.githubusercontent.com` |
| 공급자 조건 | `repository_owner == 'kiliuswook'` 이고 `ref == 'refs/heads/main'` (main 브랜치 실행만) |
| 속성 매핑 | google.subject=sub, attribute.repository, attribute.repository_owner, attribute.ref |
| 대리 권한 | `play-publisher@key-hope-514901-c5.iam.gserviceaccount.com` 에 `roles/iam.workloadIdentityUser` → `principalSet://…/workloadIdentityPools/github/attribute.repository/kiliuswook/aigyeol` 만 |
| 켠 API | sts, iam, iamcredentials, androidpublisher |
| GitHub Secrets (aigyeol) | `ANDROID_KEYSTORE_B64`(업로드 키 jks, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` — 원본 `%USERPROFILE%\keystores\childmbti` |

다른 앱 저장소도 쓰려면: 그 저장소용 principalSet 을 같은 서비스 계정에 `workloadIdentityUser` 로 더 붙이고(공급자는 그대로), 이 워크플로를 복사해 패키지 이름·키 Secrets 를 바꾼다.

## 쓰는 법

GitHub > kiliuswook/aigyeol > Actions > **Play deploy** > Run workflow (브랜치 main). 또는 `gh workflow run play-deploy.yml -R kiliuswook/aigyeol -f mode=upload -f track=beta`.

| mode | 하는 일 |
|---|---|
| check | 인증하고 트랙 상태만 읽는다(1분) |
| validate | AAB 빌드(Flutter 3.41.2) → 업로드 → 트랙 지정 → 검증만, 편집 버림. 이미 쓴 versionCode 면 업로드에서 실패 |
| upload | 위와 같고 반영(commit). 관리형 게시가 꺼져 있어 바로 Google 검토로 전송된다 |

- 버전은 `app/pubspec.yaml` 의 `version` 그대로(올리고 커밋한 뒤 실행). 출시 이름 = 그 값.
- 출시 노트: 입력 `notes` 의 JSON(기본 `release/store-global/listings.json` 의 `releaseNotes`).
- 등록정보·스크린샷·국가는 이 워크플로가 하지 않는다(`release/store-global/play_global.py`, 국가는 콘솔).
- PC 에서도 `python tools/play_deploy.py check|upload` 가 된다(그때는 gcloud 대리 인증).

## PC 재인증 줄이기 (원더 손)

워크스페이스 관리 콘솔(admin.google.com) > 보안 > 액세스 및 데이터 관리 > **Google Cloud 세션 제어** > 재인증 정책: "재인증 필요 없음"(또는 주기를 길게) → 저장.
조직 보안 설정이라 Claude 가 바꾸지 않는다. 바꾼 뒤 `gcloud auth login contact@wonderwheel.co.kr` 을 한 번 더 하면 된다.
