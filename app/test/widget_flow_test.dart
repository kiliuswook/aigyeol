import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/main.dart';
import 'package:childmbti/ui/account.dart';
import 'package:childmbti/ui/kit.dart';
import 'package:childmbti/store.dart';

Future<void> boot(WidgetTester t, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    await loadContent();
    await store.load();
  });
  store.kids = [Kid()];
  store.kidId = store.kids.first.id;
  tab.value = 0;
  await t.binding.setSurfaceSize(size);
  await t.pumpWidget(const App());
  await t.pump();
}

/// 리포트 탭 하나: 요약의 '자세히 보기'를 모두 눌러 끝까지 들어갔다가 '이전'으로 돌아온다
Future<void> walk(WidgetTester t) async {
  final n = find.byType(MoreBtn).evaluate().length;
  for (var k = 0; k < n; k++) {
    await t.ensureVisible(find.byType(MoreBtn).at(k));
    await t.tap(find.byType(MoreBtn).at(k));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('back')), findsOneWidget);
    while (find.byType(MoreBtn).evaluate().isNotEmpty) {
      await t.ensureVisible(find.byType(MoreBtn).first);
      await t.tap(find.byType(MoreBtn).first);
      await t.pumpAndSettle();
    }
    while (find.byKey(const Key('back')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('back')));
      await t.pumpAndSettle();
    }
  }
  for (final x in ['잘 통하는 말', '강점 · 살펴볼 점']) {
    if (find.text(x).evaluate().isEmpty) continue;
    await t.ensureVisible(find.text(x));
    await t.tap(find.text(x));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('back')));
    await t.pumpAndSettle();
  }
}

void main() {
  // 작은 폰(360x640)과 보통 폰(390x844) 모두에서 넘침 없이 끝까지 간다
  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('처음 → 아이 등록 → 결제 → 66문항 → 리포트 (${size.width.round()}x${size.height.round()})', (t) async {
      await boot(t, size);
      expect(find.text('시작하기'), findsOneWidget);
      await t.tap(find.text('시작하기'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '콩이');
      await t.tap(find.text('만 5세'));
      await t.pump();
      await t.tap(find.text('다음'));
      await t.pumpAndSettle();
      await t.tap(find.text('아빠'));
      await t.pump();
      await t.tap(find.text('검사 준비 끝'));
      await t.pumpAndSettle();
      expect(store.kid.name, '콩이');
      expect(store.kid.who, '아빠');
      await t.tap(find.textContaining('결제하고 검사 시작'));
      await t.pumpAndSettle();
      for (var i = 0; i < C.items.length; i++) {
        await t.tap(find.text(C.opt[i % 5]));
        await t.pumpAndSettle();
      }
      expect(tab.value, 1);
      expect(find.textContaining('정밀검사 결과'), findsOneWidget);
      // 리포트의 모든 탭, 모든 쪽을 넘겨 본다
      for (final x in ['기질', '자라는 힘', '양육자 비교', '달라진 점']) {
        await t.tap(find.text(x).first);
        await t.pumpAndSettle();
        await walk(t);
      }
      for (final k in [2, 3, 0]) {
        tab.value = k;
        await t.pumpAndSettle();
      }
      expect(find.text('리포트 보기'), findsOneWidget);
    });
  }

  testWidgets('샘플 리포트: 양육자 비교·달라진 점까지 쪽을 넘긴다', (t) async {
    await boot(t, const Size(360, 640));
    await t.tap(find.text('샘플 리포트 먼저 보기'));
    await t.pumpAndSettle();
    expect(find.textContaining('정밀검사 결과'), findsOneWidget);
    for (final x in ['자라는 힘', '양육자 비교', '달라진 점', '기질']) {
      await t.tap(find.text(x).first);
      await t.pumpAndSettle();
      await walk(t);
    }
    tab.value = 2;
    await t.pumpAndSettle();
    expect(find.text('함께 보기'), findsOneWidget);
    await t.tap(find.text('공동 양육자 초대'));
    await t.pumpAndSettle();
    expect(find.text('카카오톡'), findsOneWidget);
  });

  testWidgets('아이 추가를 그만두면 빈 아이가 남지 않는다', (t) async {
    await boot(t, const Size(390, 844));
    store.sample();
    await t.pumpAndSettle();
    await t.tap(find.text('+ 아이 추가'));
    await t.pumpAndSettle();
    expect(store.kids.length, 2);
    await t.tap(find.descendant(of: find.byType(TopBar), matching: find.byType(InkWell)));
    await t.pumpAndSettle();
    expect(store.kids.length, 1);
  });

  testWidgets('계정 화면: Firebase 없는 기기에서는 안내만', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(const MaterialApp(home: AccountScreen()));
    await t.pump();
    expect(find.textContaining('로그인과 동기화를 쓸 수 없어요'), findsOneWidget);
  });
}
