// 화면 사이 이동: 검사 시작(보상형 광고 → 검사), 다시 검사하기, 리포트로 가기
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'pay.dart';
import 'report.dart';
import 'test.dart';

Future<void> startFull(BuildContext ctx) async {
  final c = store.cur;
  if (!c.paid) {
    await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const PayScreen(retest: false)));
    return;
  }
  if (fullDone(c.ans)) {
    tab.value = 1;
    return;
  }
  await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const TestScreen()));
}

Future<void> startRetest(BuildContext ctx) =>
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const PayScreen(retest: true)));

void addCaregiver(BuildContext ctx, String n) {
  store.setWho(n);
  startFull(ctx);
}

/// 샘플 리포트: 예시 아이의 리포트를 따로 띄운다. 닫으면 사라지고 내 아이 기록에는 아무것도 남지 않는다.
Future<void> showSample(BuildContext ctx) async {
  store.openSample();
  await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SampleScreen()));
  store.closeSample();
}

class SampleScreen extends StatelessWidget {
  const SampleScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: NineBox(nSoft,
                    padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
                    child: Row(children: [
                      Tag(tr('샘플')),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr('예시 아이 콩이의 리포트예요.'), style: small)),
                      InkWell(
                        key: const Key('sample-close'),
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(width: 44, height: 44, child: Center(child: Image.asset('assets/ui/i_close.webp', width: 22, height: 22))),
                      ),
                    ])),
              ),
            ),
            Expanded(child: ListenableBuilder(listenable: store, builder: (c, _) => store.demo == null ? const SizedBox() : 
                // const 이면 양육자를 바꿔도 다시 그려지지 않는다
                // ignore: prefer_const_constructors
                ReportView())),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: SizedBox(width: double.infinity, child: Btn(tr('샘플 닫고 내 아이 검사하기'), () => Navigator.of(context).pop(), kind: BtnKind.dark))),
            ),
          ]),
        ),
      );
}
