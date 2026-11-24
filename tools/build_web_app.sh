#!/usr/bin/env bash
# 플루터 앱(app/)을 웹용으로 빌드해 저장소 루트(첫 화면)에 넣는다 → https://childmbti.wonderwheel.co.kr/
# 사용: tools/build_web_app.sh   (flutter 가 PATH 에 있어야 함). 끝나면 바뀐 파일을 커밋·푸시하면 배포된다.
# 2026-11-24 부터 첫 화면이 플루터 앱이다(예전 HTML 시제품은 git 기록에). /new/ 는 첫 화면으로 넘겨 주는 페이지만 둔다.
# 루트의 다른 파일(privacy.html, delete-account.html, go/, app-ads.txt, CNAME, assets/ 의 og·공유 그림)은 건드리지 않는다.
set -euo pipefail
cd "$(dirname "$0")/../app"
flutter build web --release --base-href / --no-web-resources-cdn
R=..
# 지난 빌드 결과만 지운다(플루터가 만드는 이름들)
rm -rf $R/canvaskit $R/icons $R/assets/assets $R/assets/fonts $R/assets/packages $R/assets/shaders
rm -f $R/main.dart.js $R/flutter.js $R/flutter_bootstrap.js $R/flutter_service_worker.js $R/version.json $R/manifest.json $R/favicon.png $R/.last_build_id \
  $R/assets/AssetManifest.bin $R/assets/AssetManifest.bin.json $R/assets/AssetManifest.json $R/assets/FontManifest.json $R/assets/NOTICES
cp -r build/web/. $R/
rm -f $R/.last_build_id
# 쓰지 않는 그리기 엔진(skwasm)과 지도 파일은 뺀다
rm -f $R/canvaskit/skwasm* $R/canvaskit/*.symbols $R/canvaskit/chromium/*.symbols
find $R/canvaskit $R/assets -name '*.map' -delete
du -sh $R/canvaskit $R/assets $R/main.dart.js
