import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'content.dart';
import 'store.dart';
import 'sync.dart';
import 'ui/kit.dart';
import 'ui/home.dart';
import 'ui/report.dart';
import 'ui/more.dart';
import 'ui/share.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([loadContent(), preloadUi(), store.load()]);
  // 웹(미리 보기)은 Firebase 웹 설정이 없어 로그인·동기화를 켜지 않는다
  if (!kIsWeb) await sync.init();
  runApp(const App());
}

/// 아래 메뉴: 0 홈, 1 리포트, 2 함께(가족 초대·공유), 3 더보기(계정·기록·안내)
final tab = ValueNotifier<int>(0);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '내 아이의 MBTI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kAccent, surface: kBg),
          scaffoldBackgroundColor: kBg,
          textTheme: const TextTheme(bodyMedium: body),
        ),
        home: const Shell(),
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
              builder: (ctx, _) => IndexedStack(index: i, children: [HomeView(), ReportView(), ShareView(), MoreView()]),
            ),
          ),
          bottomNavigationBar: NineBox(nCard,
              padding: const EdgeInsets.only(top: 6),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (final (k, label, icon) in const [(0, '홈', 'i_home'), (1, '리포트', 'i_doc'), (2, '함께', 'i_heart'), (3, '더보기', 'i_star')])
                    Expanded(
                      child: InkWell(
                        onTap: () => tab.value = k,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 56, height: 32,
                              decoration: BoxDecoration(color: i == k ? kAccent : null, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Opacity(opacity: i == k ? 1 : .55, child: Image.asset('assets/ui/$icon${i == k || icon == 'i_heart' ? '' : '_off'}.webp', width: 28, height: 28))),
                            ),
                            const SizedBox(height: 2),
                            Text(label, style: TextStyle(fontSize: 12, fontWeight: i == k ? FontWeight.w700 : FontWeight.w500, color: i == k ? kFg : kMuted)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              )),
        ),
      );
}
