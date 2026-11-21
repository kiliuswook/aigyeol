// 스토어 업데이트 알림과 평가 요청.
// - 안드로이드: 구글 플레이 인앱 업데이트. 새 버전이 있으면 뒤에서 받아 두고(유연 업데이트),
//   다 받으면 "다시 시작" 한 번으로 바뀐다. 플레이 콘솔에서 우선순위 4 이상으로 올린 버전은 바로 업데이트 화면.
// - iOS: 애플은 자동 업데이트 API 가 없어, 앱스토어 조회로 새 버전을 알고 업데이트 창을 띄운다(같은 버전은 3일에 한 번만).
// - 평가: 검사를 마친 리포트를 두 번째로 열 때 OS 기본 평가 창을 부른다. 90일에 한 번, 최대 3번.
//   "만족하세요?" 같은 먼저 묻기는 두지 않는다(플레이·애플 정책상 좋은 평가만 고르는 것처럼 보일 수 있음).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ads.dart';
import 'i18n.dart';

const kBundleId = 'kr.co.wonderwheel.childmbti';
const kAppStoreId = '6836670196';

/// 앱 위쪽 Navigator 에 닿기 위한 키(main.dart MaterialApp 에 건다)
final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class Upgrade {
  bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool _checked = false;

  /// 앱을 켜고 인트로가 끝난 뒤 한 번
  Future<void> check() async {
    if (!_mobile || _checked) return;
    _checked = true;
    try {
      if (Platform.isAndroid) {
        await _android();
      } else {
        await _ios();
      }
    } catch (e) {
      debugPrint('upgrade: $e');
    }
  }

  Future<void> _android() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress && info.installStatus == InstallStatus.downloaded) {
      _readyToRestart();
      return;
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    } else if (info.flexibleUpdateAllowed) {
      final r = await InAppUpdate.startFlexibleUpdate();
      if (r == AppUpdateResult.success) _readyToRestart();
    }
  }

  /// 새 버전을 다 받았을 때: 아래에 알림 한 줄 + 다시 시작
  void _readyToRestart() {
    messengerKey.currentState?.showSnackBar(SnackBar(
      duration: const Duration(days: 1),
      content: Text(tr('새 버전을 받았어요')),
      action: SnackBarAction(label: tr('다시 시작'), onPressed: () => unawaited(InAppUpdate.completeFlexibleUpdate())),
    ));
  }

  Future<void> _ios() async {
    final now = (await PackageInfo.fromPlatform()).version;
    String? store;
    for (final c in ['kr', 'us']) {
      final r = await http.get(Uri.parse('https://itunes.apple.com/lookup?bundleId=$kBundleId&country=$c&t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 8));
      final res = (jsonDecode(r.body)['results'] as List?) ?? const [];
      if (res.isNotEmpty) {
        store = res.first['version'] as String?;
        break;
      }
    }
    if (store == null || !newer(store, now)) return;
    final sp = await SharedPreferences.getInstance();
    final key = 'upgrade_ios_$store';
    final last = sp.getInt(key) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last < const Duration(days: 3).inMilliseconds) return;
    await sp.setInt(key, DateTime.now().millisecondsSinceEpoch);
    final ctx = navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final go = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(tr('새 버전이 나왔어요')),
        content: Text(tr('더 좋아진 {0} 버전으로 업데이트해 주세요.', [store!])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('나중에'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('업데이트'))),
        ],
      ),
    );
    if (go == true) await launchUrl(Uri.parse('https://apps.apple.com/app/id$kAppStoreId'), mode: LaunchMode.externalApplication);
  }

  // ── 평가 ──
  /// 검사를 마친 리포트가 보일 때마다 부른다
  Future<void> onReportSeen() async {
    if (!_mobile) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final seen = (sp.getInt('review_seen') ?? 0) + 1;
      await sp.setInt('review_seen', seen);
      final asked = sp.getInt('review_asked') ?? 0, last = sp.getInt('review_last') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (seen < 2 || asked >= 3 || now - last < const Duration(days: 90).inMilliseconds) return;
      // 광고가 떠 있거나 화면이 막 바뀌는 중이면 잠깐 뒤에
      await Future.delayed(const Duration(seconds: 2));
      if (ads.showing) return;
      final r = InAppReview.instance;
      if (!await r.isAvailable()) return;
      await sp.setInt('review_asked', asked + 1);
      await sp.setInt('review_last', now);
      await r.requestReview();
    } catch (e) {
      debugPrint('review: $e');
    }
  }

  /// 더보기 > 앱 평가하기: 스토어 평가 화면을 바로 연다
  Future<void> openStore() async {
    if (kIsWeb) {
      await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$kBundleId'));
      return;
    }
    await InAppReview.instance.openStoreListing(appStoreId: kAppStoreId);
  }
}

/// a 가 b 보다 새 버전인지(1.2.10 > 1.2.9)
bool newer(String a, String b) {
  List<int> p(String s) => s.split('+').first.split('.').map((x) => int.tryParse(x) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}

final upgrade = Upgrade();
