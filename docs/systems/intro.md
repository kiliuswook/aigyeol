# 인트로 (스플래시 · 타이틀)

- 최종 수정일: 2026-11-19
- 버전: 1.0.2

앱을 켤 때마다 한 번: 원더휠 스플래시 → 타이틀 화면 → 홈. 코드는 `app/lib/ui/intro.dart`, 지났는지는 `introDone`(main.dart 가 보고 홈으로 바꾼다).

## 원더휠 스플래시

- 원더가 만든 원더휠 CI 영상 `WONDERWHEEL_CI_FINAL_V33` 밝은 판 세로를 그대로 튼다. 흰 바탕, 5초, 소리 없음(음소거로 재생).
  - 휴대폰 세로 1080x1920: `app/assets/video/wonderwheel_portrait.mp4` (0.43MB)
  - 태블릿 세로 1440x1920: `app/assets/video/wonderwheel_tablet.mp4` (0.50MB). 화면 가로/세로 비율이 0.66 보다 크면 이 판.
  - 원본: 원더 구글 드라이브 CI 폴더 `Final_ver`(1Ddocodhv16Rw7wbgjh6uDg3atN7Psl-h). 어두운 판·가로 판도 있다.
- 영상은 잘리지 않게 화면 안에 맞춰(contain) 흰 바탕 가운데 보인다.
- 영상이 끝나면 타이틀로 넘어간다. 0.5초 뒤부터 화면을 터치하면 건너뛴다.
- 영상을 열지 못하면(3초 안에 시작 못 함, 테스트 환경 포함) 로고 그림 `app/assets/img/wonderwheel.png`(홈페이지 logo-black.png 를 1024px 로)를 1.8초 보여 주고 넘어간다.
- 패키지 `video_player`. 웹·안드로이드·iOS 모두 같은 영상.

## 타이틀 화면

- 대표 그림, 앱 이름, 소개 두 줄, 가격 줄, 깜빡이는 "화면을 터치하면 시작해요". 버튼은 없다(시작하기·샘플 리포트 보기는 홈에 있다).
- 화면 어디든 터치하면 홈으로 간다.
