import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ads.dart';
import 'content.dart';
import 'stats.dart';
import 'store.dart';
import 'sync.dart';
import 'ui/kit.dart';
import 'ui/home.dart';
import 'ui/intro.dart';
import 'ui/report.dart';
import 'ui/more.dart';
import 'ui/links.dart' show initKakao;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initKakao();
  await Future.wait([loadContent(), preloadUi(), store.load()]);
  // 웹(미리 보기)은 Firebase 웹 설정이 없어 로그인·동기화를 켜지 않는다
  if (!kIsWeb) await sync.init();
  // 예전에 마친 검사 중 아직 통계에 넣지 않은 것을 보낸다
  unawaited(stats.submitPending());
  runApp(const App());
  // 광고 동의(유럽 등)와 AdMob 초기화는 화면을 띄운 뒤에
  unawaited(ads.init());
  // 아래 메뉴를 옮기는 것도 페이지 전환으로 센다
  tab.addListener(ads.onPageChange);
}

/// 아래 메뉴: 0 홈, 1 리포트, 2 더보기(가족 초대·공유, 계정, 안내)
final tab = ValueNotifier<int>(0);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '내 아이의 MBTI',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [AdRouteObserver()],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kAccent, surface: kBg),
          scaffoldBackgroundColor: kBg,
          textTheme: const TextTheme(bodyMedium: body),
        ),
        home: ValueListenableBuilder(valueListenable: introDone, builder: (_, done, _) => AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: done ? const Shell() : const Intro())),
      );
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
              listenable: store,
              // const 로 두면 store 가 바뀌어도 화면이 다시 그려지지 않는다
              builder: (ctx, _) => IndexedStack(index: i, children: [HomeView(), ReportView(), MoreView()]),
            ),
          ),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            const BannerBox(),
            NineBox(nCard,
              padding: const EdgeInsets.only(top: 6),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (final (k, label, icon) in const [(0, '홈', 'i_home'), (1, '리포트', 'i_doc'), (2, '더보기', 'i_star')])
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
