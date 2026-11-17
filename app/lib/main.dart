import 'package:flutter/material.dart';
import 'content.dart';
import 'store.dart';
import 'sync.dart';
import 'ui/kit.dart';
import 'ui/home.dart';
import 'ui/report.dart';
import 'ui/share.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([loadContent(), preloadUi(), store.load()]);
  await sync.init();
  runApp(const App());
}

/// 아래 메뉴: 0 홈, 1 리포트, 2 공유
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
              builder: (ctx, _) => IndexedStack(index: i, children: [HomeView(), ReportView(), ShareView()]),
            ),
          ),
          bottomNavigationBar: NineBox(nCard,
              padding: const EdgeInsets.only(top: 6),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (final (k, label, icon) in const [(0, '홈', 'i_home'), (1, '리포트', 'i_doc'), (2, '공유', 'i_share')])
                    Expanded(
                      child: InkWell(
                        onTap: () => tab.value = k,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 56, height: 32,
                              decoration: BoxDecoration(color: i == k ? kAccent : null, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Opacity(opacity: i == k ? 1 : .55, child: Image.asset('assets/ui/$icon${i == k || icon == 'i_share' ? '' : '_off'}.webp', width: 28, height: 28))),
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

/// 화면 공통 틀: 가운데 정렬, 최대 폭 480, 위 상표줄
class AppPage extends StatelessWidget {
  final List<Widget> children;
  final bool brand;
  const AppPage(this.children, {super.key, this.brand = true});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: col([
                if (brand)
                  Row(children: [
                    Image.asset('assets/img/mascot_child.webp', width: 34, height: 34),
                    const SizedBox(width: 8),
                    Text('내 아이의 MBTI', style: disp(22)),
                    const SizedBox(width: 6),
                    const Flexible(child: Text('영유아 기질검사', style: smallMuted, overflow: TextOverflow.ellipsis)),
                  ]),
                ...children,
              ], gap: 18),
            ),
          ),
        ],
      );
}
