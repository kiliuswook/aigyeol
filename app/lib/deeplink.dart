// 앱으로 들어오는 링크: 이미 설치된 앱을 여는 링크(childmbti://open?…)와, 스토어에서 막 설치한 앱이 처음 켜질 때 받는 설치 정보.
// 설명 docs/systems/share-links.md
//
// - 공유 링크는 https://childmbti.wonderwheel.co.kr/go/#… (web/go/index.html). 그 페이지가 안드로이드에서는 앱을 열고,
//   앱이 없으면 구글 플레이로 보내며 링크 값을 설치 정보(referrer)로 넘긴다. 아이폰은 앱스토어로 보낸다.
// - 안드로이드: 설치 뒤 처음 켤 때 플레이 설치 정보(MainActivity.kt 'referrer')를 한 번 읽어 초대를 이어 간다.
// - 아이폰: 앱스토어는 설치 정보를 넘겨주지 않아, 초대 문구의 '초대 코드'를 앱에서 입력한다(더보기 · 처음 화면).
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'upgrade.dart' show navKey;
import 'ui/intro.dart' show introDone;
import 'ui/land.dart';
import 'ui/links.dart';

const _ch = MethodChannel('childmbti/share');
const _kRefDone = 'childmbti_ref_done';

class DeepLinks {
  StreamSubscription? _sub;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      final al = AppLinks();
      _sub = al.uriLinkStream.listen((u) => _handle('$u'));
      // 처음 링크는 uriLinkStream 이 한 번 보내 준다(app_links 7). 플레이 설치 정보는 따로 읽는다.
    } catch (e) {
      debugPrint('app links: $e');
    }
    unawaited(_referrer());
  }

  /// 설치 뒤 처음 한 번: 플레이 설치 정보에 실린 링크 값(예: f=ABCDE12345)
  Future<void> _referrer() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_kRefDone) ?? false) return;
      final r = await _ch.invokeMethod<String>('referrer');
      // 플레이가 답을 못 주면(null) 다음에 켤 때 다시 본다
      if (r == null) return;
      await sp.setBool(_kRefDone, true);
      final l = Landing.parse('childmbti://open?$r');
      if (l != null) _open(l);
    } catch (e) {
      debugPrint('install referrer: $e');
    }
  }

  void _handle(String link) {
    final l = Landing.parse(link);
    if (l != null) _open(l);
  }

  /// 인트로가 끝나고 홈이 뜬 뒤에 받은 링크 화면을 연다
  void _open(Landing l) {
    void go() {
      if (!introDone.value) return;
      introDone.removeListener(go);
      Future.delayed(const Duration(milliseconds: 400), () => navKey.currentState?.push(MaterialPageRoute(builder: (_) => LandScreen(l))));
    }

    if (introDone.value) {
      go();
    } else {
      introDone.addListener(go);
    }
  }

  void dispose() => _sub?.cancel();
}

final deepLinks = DeepLinks();
