#!/usr/bin/env bash
# 플루터 앱(app/)을 웹용으로 빌드해 저장소의 new/ 폴더에 넣는다 → https://childmbti.wonderwheel.co.kr/new/
# 사용: tools/build_web_app.sh   (flutter 가 PATH 에 있어야 함). 끝나면 new/ 를 커밋·푸시하면 배포된다.
set -euo pipefail
cd "$(dirname "$0")/../app"
flutter build web --release --base-href /new/ --no-web-resources-cdn
rm -rf ../new
cp -r build/web ../new
# 쓰지 않는 그리기 엔진(skwasm)과 지도 파일은 뺀다
rm -f ../new/canvaskit/skwasm* ../new/canvaskit/*.symbols ../new/canvaskit/chromium/*.symbols
find ../new -name '*.map' -delete
du -sh ../new
