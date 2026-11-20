// 광고(AdMob): 검사 시작 전 보상형 광고, 아래 메뉴 위 배너, 페이지를 옮길 때 3분에 한 번 앱 오프닝 광고.
// 광고 ID는 이 파일 한곳. 디버그 빌드는 구글 테스트 ID로 돌아서 실제 광고를 누를 걱정이 없다.
// 설명: docs/systems/ads.md
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 앱 ID 는 AndroidManifest.xml(com.google.android.gms.ads.APPLICATION_ID)과 Info.plist(GADApplicationIdentifier)에 있다.
class AdIds {
  static const _pub = 'ca-app-pub-8781487635021961';
  static bool get _ios => Platform.isIOS;

  static String get banner => kReleaseMode
      ? (_ios ? '$_pub/1351535601' : '$_pub/5482352300')
      : (_ios ? 'ca-app-pub-3940256099942544/2435281174' : 'ca-app-pub-3940256099942544/9214589741');
  static String get rewarded => kReleaseMode
      ? (_ios ? '$_pub/5121379322' : '$_pub/2894671239')
      : (_ios ? 'ca-app-pub-3940256099942544/1712485313' : 'ca-app-pub-3940256099942544/5224354917');
  static String get appOpen => kReleaseMode
      ? (_ios ? '$_pub/5159365789' : '$_pub/6370881815')
      : (_ios ? 'ca-app-pub-3940256099942544/5575463023' : 'ca-app-pub-3940256099942544/9257395921');
}

/// 앱 오프닝 광고 사이 최소 간격(원더 2026-11-20: 페이지 전환 시 3분에 한 번)
const kOpenGap = Duration(minutes: 3);

class Ads {
  /// 휴대폰 앱에서만 광고를 쓴다(웹 미리 보기·테스트에서는 꺼짐)
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 동의(유럽 등)와 SDK 초기화가 끝나 광고를 요청해도 되는지
  final ready = ValueNotifier<bool>(false);

  RewardedAd? _rewarded;
  bool _rewardedLoading = false;
  AppOpenAd? _open;
  DateTime? _openLoadedAt;
  bool _openLoading = false;
  bool _showing = false;
  // 앱을 켠 뒤 3분이 지나야 첫 앱 오프닝 광고가 나온다
  DateTime _lastFull = DateTime.now();

  Future<void>? _init;

  /// 여러 곳에서 불러도 한 번만 준비한다(실패했으면 다음에 다시 시도).
  Future<void> init() {
    if (!supported || ready.value) return Future.value();
    return _init ??= _doInit().whenComplete(() => _init = null);
  }

  Future<void> _doInit() async {
    try {
      await _consent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      // 부모용 앱이지만 아이를 다루는 앱이라 광고 수위는 PG 까지로 둔다
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
      ));
      ready.value = true;
      _loadRewarded();
      _loadOpen();
    } catch (e) {
      debugPrint('ads init: $e');
    }
  }

  /// 유럽·영국 등에서 필요한 광고 동의 창(AdMob 개인 정보 보호 및 메시지에서 만든 메시지)을 띄운다
  Future<void> _consent() {
    final done = Completer<void>();
    void finish([_]) {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () {
      ConsentForm.loadAndShowConsentFormIfRequired(finish);
    }, finish);
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// 광고 설정 다시 열기(동의를 바꾸고 싶을 때). 필요 없는 지역이면 false.
  Future<bool> privacyOptionsRequired() async =>
      supported && await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;

  Future<void> showPrivacyOptions() async {
    final c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => c.complete());
    return c.future;
  }

  // ---------- 보상형: 검사 열기 ----------
  void _loadRewarded() {
    if (!ready.value || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedLoading = false;
        },
        onAdFailedToLoad: (e) {
          debugPrint('rewarded load: $e');
          _rewardedLoading = false;
        },
      ),
    );
  }

  /// 보상형 광고를 보여 준다. 결과: shown(끝까지 봄), skipped(중간에 닫음), none(보여 줄 광고가 없음).
  /// 광고가 없을 때(광고 미지원 기기, 인터넷 끊김, 광고 재고 없음)는 검사를 막지 않는다.
  Future<RewardResult> showRewarded() async {
    if (!supported) return RewardResult.none;
    if (!ready.value) await init();
    if (!ready.value) return RewardResult.none;
    _loadRewarded();
    // 아직 받는 중이면 잠깐(최대 8초) 기다린다
    for (var i = 0; i < 16 && _rewarded == null && _rewardedLoading; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final ad = _rewarded;
    if (ad == null) return RewardResult.none;
    _rewarded = null;
    final out = Completer<RewardResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _afterFull();
        if (!out.isCompleted) out.complete(earned ? RewardResult.shown : RewardResult.skipped);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _afterFull();
        if (!out.isCompleted) out.complete(RewardResult.none);
      },
    );
    _showing = true;
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return out.future;
  }

  void _afterFull() {
    _showing = false;
    _lastFull = DateTime.now();
    _loadRewarded();
  }

  // ---------- 앱 오프닝: 페이지 전환 때 3분에 한 번 ----------
  bool get _openFresh => _open != null && _openLoadedAt != null && DateTime.now().difference(_openLoadedAt!) < const Duration(hours: 4);

  void _loadOpen() {
    if (!ready.value || _openLoading || _openFresh) return;
    _open?.dispose();
    _open = null;
    _openLoading = true;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _open = ad;
          _openLoadedAt = DateTime.now();
          _openLoading = false;
        },
        onAdFailedToLoad: (e) {
          debugPrint('app open load: $e');
          _openLoading = false;
        },
      ),
    );
  }

  /// 페이지가 바뀔 때마다 부른다. 마지막 전면 광고(앱 오프닝·보상형)에서 3분이 지났을 때만 보여 준다.
  void onPageChange() {
    if (!ready.value || _showing) return;
    if (DateTime.now().difference(_lastFull) < kOpenGap) return;
    if (!_openFresh) {
      _loadOpen();
      return;
    }
    final ad = _open!;
    _open = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showing = false;
        _lastFull = DateTime.now();
        _loadOpen();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _showing = false;
        _loadOpen();
      },
    );
    _showing = true;
    ad.show();
  }
}

enum RewardResult { shown, skipped, none }

final ads = Ads();

/// 화면 이동을 지켜보다가 앱 오프닝 광고를 띄운다. 가운데 팝업창(대화상자)은 페이지 전환으로 치지 않는다.
class AdRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute && previousRoute != null) _later();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PageRoute) _later();
  }

  // 화면 전환 애니메이션이 끝난 뒤에 띄운다
  void _later() => Future.delayed(const Duration(milliseconds: 400), ads.onPageChange);
}

/// 아래 메뉴 위에 붙는 배너. 광고가 없으면 자리를 차지하지 않는다.
class BannerBox extends StatefulWidget {
  const BannerBox({super.key});
  @override
  State<BannerBox> createState() => _BannerBoxState();
}

class _BannerBoxState extends State<BannerBox> {
  BannerAd? _ad;
  bool _loaded = false;
  int _width = 0;

  @override
  void initState() {
    super.initState();
    ads.ready.addListener(_retry);
  }

  void _retry() {
    if (mounted) setState(() {});
  }

  Future<void> _load(int width) async {
    _width = width;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, e) {
          debugPrint('banner load: $e');
          a.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    ads.ready.removeListener(_retry);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Ads.supported || !ads.ready.value) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (_ad == null && _width != w) _load(w);
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad));
  }
}
