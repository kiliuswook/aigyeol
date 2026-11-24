import 'i18n.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ads.dart';
import 'content.dart';
import 'daily.dart';
import 'dev.dart';
import 'notify.dart';
import 'stats.dart';
import 'scoring.dart';
import 'store.dart';
import 'sync.dart';
import 'ui/kit.dart';
import 'ui/home.dart';
import 'ui/intro.dart';
import 'ui/report.dart';
import 'ui/more.dart';
import 'ui/today.dart';
import 'ui/sibling.dart' show sibOther;
import 'ui/links.dart' show initKakao;
import 'deeplink.dart';
import 'fam.dart';
import 'upgrade.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initKakao();
  // 첫 화면에 꼭 필요한 것(문항·손그림 테두리·이 폰 기록)만 기다리고 바로 화면을 띄운다
  // 언어(저장된 선택, 없으면 기기 언어)를 먼저 정해야 문항·오늘 탭 문구를 그 언어로 읽는다
  await loadLang();
  await Future.wait([loadContent(), loadDaily(), loadDev(), preloadUi(), store.load(), daily.load()]);
  runApp(const App());
  // 로그인·동기화(Firebase)는 화면을 띄운 뒤에 연다. 기다리면 앱을 켤 때 빈 화면이 그만큼 길어진다.
  // 웹(미리 보기)은 Firebase 웹 설정이 없어 로그인·동기화를 켜지 않는다
  // 가족 연결(fam.dart)도 Firebase 가 열린 뒤에: 다른 휴대폰의 양육자 결과 받기, 바뀐 결과 올리기
  if (!kIsWeb) unawaited(sync.init().then((_) => fam.pull(force: true)));
  store.addListener(fam.schedule);
  // 받은 링크(이미 설치된 앱 열기)와 설치 뒤 처음 켤 때의 플레이 설치 정보
  unawaited(deepLinks.init());
  // 예전에 마친 검사 중 아직 통계에 넣지 않은 것을 보낸다
  unawaited(stats.submitPending());
  unawaited(devStats.submitPending());
  // 광고 동의(유럽 등)와 AdMob 초기화는 스플래시 영상이 끝난 뒤(intro.dart toTitle)에 한다.
  // 영상과 겹치면 광고 SDK 준비 때문에 영상이 끊긴다.
  // 인트로를 건너뛴 경우에도 광고는 준비한다(이미 준비 중이면 그대로)
  introDone.addListener(() => unawaited(ads.init()));
  // 오늘의 미션·약속 알림(켠 사람만): 날짜가 바뀌어도 앞으로 7일 치가 걸려 있게 앱을 켤 때마다 다시 건다
  unawaited(notify.reschedule());
  // 미션은 매일 오전 9시에 바뀐다: 켜 둔 동안 9시가 지나면, 그리고 앱을 다시 열 때마다 새 미션으로
  daily.startClock();
  AppLifecycleListener(onResume: () {
    unawaited(fam.pull());
    daily.refresh();
    daily.startClock();
  });
  // 처음 한 번, 인트로가 끝난 뒤 푸시 알림 권한을 묻는다(알림은 기본 켜짐, 더보기 > 푸시 알림에서 끔)
  void askOnce() {
    if (!introDone.value || daily.asked || !notify.supported) return;
    daily.asked = true;
    daily.save();
    unawaited(notify.ask().then((_) => notify.reschedule()));
  }
  introDone.addListener(askOnce);
  askOnce();
  // 아래 메뉴를 옮기는 것도 페이지 전환으로 센다
  tab.addListener(ads.onPageChange);
  // 스토어 새 버전 확인(안드로이드는 뒤에서 받아 두기, iOS 는 업데이트 창): 인트로가 끝난 뒤 한 번
  void checkUpdate() {
    if (introDone.value) unawaited(Future.delayed(const Duration(seconds: 3), upgrade.check));
  }
  introDone.addListener(checkUpdate);
  checkUpdate();
  // 평가 요청: 검사를 마친 리포트를 볼 때(조건은 upgrade.dart)
  tab.addListener(() {
    if (tab.value == 1) unawaited(fam.pull());
    if (tab.value == 1 && store.cur.paid && fullDone(store.cur.ans)) unawaited(upgrade.onReportSeen());
  });
}

/// 아래 메뉴: 0 홈, 1 리포트, 2 더보기(가족 초대·공유, 계정, 안내), 3 오늘(미션·약속·상황 카드).
/// 화면에 놓이는 순서는 홈 · 오늘 · 리포트 · 더보기(번호는 예전 그대로 두어 tab.value = 1 이 리포트).
final tab = ValueNotifier<int>(0);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: lang, builder: (_, l, _) => MaterialApp(
        key: ValueKey(l),
        title: tr('내 아이의 MBTI'),
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        scaffoldMessengerKey: messengerKey,
        navigatorObservers: [AdRouteObserver()],
        // 날짜·시각 고르기 창도 앱 언어로
        locale: Locale(l),
        supportedLocales: [for (final c in kLangs.keys) Locale(c)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kAccent, surface: kBg),
          scaffoldBackgroundColor: kBg,
          textTheme: const TextTheme(bodyMedium: body),
          // 안드로이드 기본 화면 넘김(0.45초, 화면 전체를 겹쳐 흐리기)은 손그림 화면에서 무겁고 느리게 느껴져
          // 짧게 밀며 나타나기로 바꾼다. iOS 는 밀어서 뒤로 가기가 있어 기본 그대로.
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: QuickPageTransitions(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          }),
        ),
        home: ValueListenableBuilder(valueListenable: introDone, builder: (_, done, _) => AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: done ? const Shell() : const Intro())),
      ));
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: tab,
        builder: (ctx, i, _) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: Listenable.merge([store, sibOther]),
              // 보고 있는 탭만 다시 그린다. 안 보이는 탭은 열 때 한 번 다시 그린다(검사 중 답할 때마다 세 탭을 모두 그리지 않게).
              builder: (ctx, _) => IndexedStack(index: i, children: [
                for (var k = 0; k < 4; k++) _TabPage(active: i == k, build: () => switch (k) { 0 => HomeView(), 1 => ReportView(), 2 => MoreView(), _ => TodayView() }),
              ]),
            ),
          ),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            const BannerBox(),
            NineBox(nCard,
              padding: const EdgeInsets.only(top: 6),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (final (k, label, icon) in [(0, tr('홈'), 'i_home'), (3, tr('오늘'), 'i_chat'), (1, tr('리포트'), 'i_doc'), (2, tr('더보기'), 'i_star')])
                    Expanded(
                      child: InkWell(
                        onTap: () => tab.value = k,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 56, height: 32,
                              decoration: BoxDecoration(color: i == k ? kAccent : null, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Opacity(opacity: i == k ? 1 : .55, child: Image.asset('assets/ui/$icon${i == k ? '' : '_off'}.webp', width: 28, height: 28))),
                            ),
                            const SizedBox(height: 2),
                            Text(label, style: TextStyle(fontSize: 12, fontWeight: i == k ? FontWeight.w700 : FontWeight.w500, color: i == k ? kFg : kMuted)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              )),
          ]),
        ),
      );
}

/// 아래 메뉴 탭 한 칸. 한 번도 열지 않은 탭은 만들지 않고, 안 보이는 동안에는 전에 그린 것을 그대로 둔다.
class _TabPage extends StatefulWidget {
  final bool active;
  final Widget Function() build;
  const _TabPage({required this.active, required this.build});
  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  Widget? _child;
  @override
  Widget build(BuildContext context) {
    // 같은 위젯 객체를 돌려주면 플러터는 그 아래를 다시 그리지 않는다
    if (widget.active) _child = widget.build();
    return _child ?? const SizedBox.shrink();
  }
}

/// 짧은 화면 넘김: 새 화면이 오른쪽에서 살짝 밀려 들어오며 나타난다(0.22초). 뒤로 갈 때는 반대로.
class QuickPageTransitions extends PageTransitionsBuilder {
  const QuickPageTransitions();
  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);
  static final _slide = Tween(begin: const Offset(.06, 0), end: Offset.zero);
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(position: _slide.animate(a), child: FadeTransition(opacity: a, child: child));
  }
}
