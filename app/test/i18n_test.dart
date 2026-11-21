// 영어 화면 점검: 모든 탭을 돌며 넘침이 없는지, 화면에 한국어가 남지 않았는지 본다.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/daily.dart';
import 'package:childmbti/i18n.dart';
import 'package:childmbti/notify.dart';
import 'package:childmbti/main.dart';
import 'package:childmbti/stats.dart';
import 'package:childmbti/store.dart';
import 'package:childmbti/ui/intro.dart';
import 'package:childmbti/ui/kit.dart';
import 'package:childmbti/ui/today.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _hangul = RegExp('[가-힣]');

/// 화면에 보이는 글 중 한국어가 든 것
List<String> korean(WidgetTester t) => [
      for (final e in find.byType(RichText).evaluate())
        if (_hangul.hasMatch((e.widget as RichText).text.toPlainText())) (e.widget as RichText).text.toPlainText(),
    ];

Future<void> boot(WidgetTester t, String code) async {
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    await setLang(code, () async => Future.wait([loadContent(), loadDaily()]));
    await store.load();
    await daily.load();
  });
  notify.off = true;
  daily.days.clear();
  daily.plans.clear();
  todaySeg.value = 0;
  store.kids = [Kid()];
  store.kidId = store.kids.first.id;
  stats.clear();
  stats.client = MockClient((q) async => http.Response('{"fields":{"n":{"integerValue":"9"},"sA":{"integerValue":"450"}}}', 200));
  tab.value = 0;
  introDone.value = true;
  await t.binding.setSurfaceSize(const Size(360, 640));
}

Future<void> check(WidgetTester t, String where) async {
  await t.pumpAndSettle();
  final k = korean(t);
  expect(k, isEmpty, reason: '$where: $k');
}

void main() {
  tearDown(() async {
    await setLang('ko', () async => Future.wait([loadContent(), loadDaily()]));
  });

  for (final code in kLangs.keys.where((c) => c != 'ko' && _ready(c))) {
  testWidgets('$code: 첫 화면 · 아이 등록', (t) async {
    await boot(t, code);
    await t.pumpWidget(const App());
    await check(t, 'home first');
    await t.tap(find.text(tr('시작하기')));
    await check(t, 'setup');
  });

  testWidgets('$code: 두 아이·두 양육자 결과로 모든 탭 (360x640)', (t) async {
    await boot(t, code);
    store.setInfo(name: 'Kongi');
    for (final it in C.items) {
      store.answer(it, 5);
    }
    store.setWho('아빠');
    for (final it in C.items) {
      store.answer(it, it.id.hashCode % 5 + 1);
    }
    store.addKid();
    store.setInfo(name: 'Byeol');
    for (final it in C.items) {
      store.answer(it, 1);
    }
    store.setKid(store.kids.first.id);
    await t.pumpWidget(const App());
    await check(t, 'home');
    tab.value = 1;
    await check(t, 'report');
    for (final name in [tr('기질'), tr('자라는 힘'), tr('양육자 비교'), tr('달라진 점'), tr('형제')]) {
      if (find.text(name).evaluate().isEmpty) continue;
      await t.tap(find.text(name).first);
      await check(t, 'report $name');
      final n = find.byType(MoreBtn).evaluate().length;
      for (var k = 0; k < n; k++) {
        await t.ensureVisible(find.byType(MoreBtn).at(k));
        await t.tap(find.byType(MoreBtn).at(k));
        await check(t, 'report $name more $k');
        while (find.byKey(const Key('back')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const Key('back')));
          await t.pumpAndSettle();
        }
      }
    }
    tab.value = 3;
    for (var i = 0; i < 3; i++) {
      todaySeg.value = i;
      await check(t, 'today $i');
    }
    tab.value = 2;
    await check(t, 'more');
  });
  }
}

/// 번역 파일이 있는 언어만
bool _ready(String c) => File('assets/i18n/$c.json').existsSync();
