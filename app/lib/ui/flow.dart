// 화면 사이 이동: 검사 시작(결제 → 검사), 다시 검사하기, 리포트로 가기
import 'package:flutter/material.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'pay.dart';
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
