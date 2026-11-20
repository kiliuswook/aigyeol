import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/daily.dart';
import 'package:childmbti/notify.dart';
import 'package:childmbti/main.dart';
import 'package:childmbti/scoring.dart';
import 'package:childmbti/ui/account.dart';
import 'package:childmbti/ui/intro.dart';
import 'package:childmbti/ui/kit.dart';
import 'package:childmbti/ui/today.dart';
import 'package:childmbti/stats.dart';
import 'package:childmbti/store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 통계 서버로 보낸 요청들
final sent = <String>[];

/// 서버에 모인 검사 건수(가짜)
var statN = 3;

Future<void> boot(WidgetTester t, Size size, {bool intro = false}) async {
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    await loadContent();
    await loadDaily();
    await store.load();
    await daily.load();
  });
  notify.off = true;
  daily.days.clear();
  daily.plans.clear();
  todaySeg.value = 0;
  store.kids = [Kid()];
  store.kidId = store.kids.first.id;
  sent.clear();
  statN = 3;
  stats.clear();
  stats.client = MockClient((q) async {
    if (q.method == 'POST') sent.add(q.body);
    return http.Response(q.method == 'POST' ? '{}' : '{"fields":{"n":{"integerValue":"$statN"},"sA":{"integerValue":"150"},"sG1":{"integerValue":"300"}}}', 200);
  });
  tab.value = 0;
  introDone.value = !intro;
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
    // 상세 안의 자세히 보기는 화면을 옮기지 않고 팝업창을 띄운다
    if (find.byType(MoreBtn).evaluate().isNotEmpty) {
      await t.ensureVisible(find.byType(MoreBtn).first);
      await t.tap(find.byType(MoreBtn).first);
      await t.pumpAndSettle();
      expect(find.textContaining('이런 말은 피해 주세요'), findsOneWidget);
      await t.tap(find.byKey(const Key('popup-close')));
      await t.pumpAndSettle();
      await t.tap(find.text('기질 설명'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('popup-close')));
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
    testWidgets('처음 → 아이 등록 → 광고 → 66문항 → 리포트 (${size.width.round()}x${size.height.round()})', (t) async {
      await boot(t, size);
      expect(find.text('시작하기'), findsOneWidget);
      await t.tap(find.text('시작하기'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '콩이');
      final by = DateTime.now().year - 5;
      await t.tap(find.text('태어난 해'));
      await t.pumpAndSettle();
      await t.tap(find.text('$by년').last);
      await t.pumpAndSettle();
      await t.tap(find.text('태어난 달'));
      await t.pumpAndSettle();
      await t.tap(find.text('1월').last);
      await t.pumpAndSettle();
      expect(store.kid.birth, '$by-01');
      await t.tap(find.text('남자아이'));
      await t.pump();
      expect(store.kid.sex, 'M');
      expect(store.kid.age, startsWith('만 '));
      await t.tap(find.text('다음'));
      await t.pumpAndSettle();
      await t.tap(find.text('아빠'));
      await t.pump();
      await t.tap(find.text('검사 준비 끝'));
      await t.pumpAndSettle();
      expect(store.kid.name, '콩이');
      expect(store.kid.who, '아빠');
      await t.tap(find.textContaining('광고 보고 무료로 검사 시작'));
      await t.pumpAndSettle();
      for (var i = 0; i < C.items.length; i++) {
        await t.tap(find.text(C.opt[i % 5]));
        await t.pumpAndSettle();
      }
      expect(tab.value, 1);
      expect(find.textContaining('정밀검사 결과'), findsOneWidget);
      // 홈의 결과 공유는 더보기로 가지 않고 공유 창을 바로 연다
      tab.value = 0;
      await t.pumpAndSettle();
      await t.tap(find.text('결과 공유'));
      await t.pumpAndSettle();
      expect(tab.value, 0);
      expect(find.text('카카오톡'), findsOneWidget);
      await t.tap(find.byKey(const Key('popup-close')));
      await t.pumpAndSettle();
      tab.value = 1;
      await t.pumpAndSettle();
      // 끝난 검사는 나이·성별 묶음으로 통계에 한 번만 보낸다
      await t.runAsync(() => stats.submitPending());
      expect(sent.length, 1);
      expect(sent.first, contains('/stats/y'));
      expect(sent.first, contains('_M'));
      expect(store.cur.st, true);
      await t.runAsync(() => stats.submitPending());
      expect(sent.length, 1);
      // 지표 옆 아이콘: 5건 이상 모인 지표만 평균이 나온다
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('avg-A')));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.textContaining('평균 준비 중'), findsOneWidget);
      await t.tap(find.byKey(const Key('popup-close')));
      await t.pumpAndSettle();
      statN = 6;
      stats.clear();
      await t.tap(find.text('자라는 힘').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('avg-G1')));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.text('또래 평균'), findsOneWidget);
      expect(find.textContaining('6건'), findsOneWidget);
      await t.tap(find.byKey(const Key('popup-close')));
      await t.pumpAndSettle();
      // 리포트의 모든 탭, 모든 쪽을 넘겨 본다
      for (final x in ['기질', '자라는 힘', '양육자 비교', '달라진 점']) {
        await t.tap(find.text(x).first);
        await t.pumpAndSettle();
        await walk(t);
      }
      // 양육자 비교의 '다른 휴대폰으로 초대 보내기' 는 더보기 탭으로 가지 않고 초대 창을 바로 연다
      await t.tap(find.text('양육자 비교').first);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('다른 휴대폰으로 초대 보내기'));
      await t.tap(find.text('다른 휴대폰으로 초대 보내기'));
      await t.pumpAndSettle();
      expect(find.textContaining('검사하게 초대'), findsOneWidget);
      expect(tab.value, 1);
      await t.tap(find.byKey(const Key('popup-close')));
      await t.pumpAndSettle();
      for (final k in [2, 0]) {
        tab.value = k;
        await t.pumpAndSettle();
      }
      expect(find.text('리포트 보기'), findsOneWidget);
    });
  }

  testWidgets('아이 등록: 기타 양육자는 이름을 직접 적는다', (t) async {
    await boot(t, const Size(390, 844));
    await t.tap(find.text('시작하기'));
    await t.pumpAndSettle();
    await t.tap(find.text('다음'));
    await t.pumpAndSettle();
    await t.tap(find.text('기타 양육자'));
    await t.pumpAndSettle();
    // 빈 이름은 받지 않는다
    await t.tap(find.text('확인'));
    await t.pump();
    expect(find.text('이름을 적어 주세요.'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '이모');
    await t.tap(find.text('확인'));
    await t.pumpAndSettle();
    expect(store.kid.who, '이모');
    expect(find.text('이모'), findsOneWidget);
  });

  testWidgets('인트로: 원더휠 스플래시 → 타이틀(버튼 없음) → 화면을 터치하면 홈', (t) async {
    await boot(t, const Size(360, 640), intro: true);
    expect(find.byKey(const ValueKey('splash')), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
    await t.pump(const Duration(milliseconds: 1900));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('화면을 터치하면 시작해요'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
    expect(find.text('샘플 리포트 먼저 보기'), findsNothing);
    await t.tap(find.byKey(const Key('intro')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(introDone.value, true);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('샘플 리포트 먼저 보기'), findsOneWidget);
  });

  testWidgets('인트로: 스플래시 중 화면을 터치하면 바로 타이틀로(그 터치로 홈까지 가지는 않음)', (t) async {
    await boot(t, const Size(360, 640), intro: true);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('화면을 터치하면 시작해요'), findsNothing);
    await t.tap(find.byKey(const Key('intro')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('화면을 터치하면 시작해요'), findsOneWidget);
    expect(introDone.value, false);
    await t.tap(find.byKey(const Key('intro')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(introDone.value, true);
  });

  testWidgets('샘플 리포트: 끝까지 보고 닫아도 내 아이 기록에 아무것도 남지 않는다', (t) async {
    await boot(t, const Size(360, 640));
    await t.tap(find.text('샘플 리포트 먼저 보기'));
    await t.pumpAndSettle();
    expect(find.textContaining('정밀검사 결과'), findsOneWidget);
    expect(find.textContaining('예시 아이 콩이의 리포트예요'), findsOneWidget);
    for (final x in ['자라는 힘', '양육자 비교', '달라진 점', '기질']) {
      await t.tap(find.text(x).first);
      await t.pumpAndSettle();
      await walk(t);
    }
    // 양육자를 바꾸면 그 사람의 결과로 바뀐다
    await t.tap(find.textContaining('아빠 · ').first);
    await t.pumpAndSettle();
    expect(store.kid.who, '아빠');
    expect(find.textContaining(store.kid.who == '아빠' ? 'ESTP' : 'ISTJ'), findsWidgets);
    await t.tap(find.textContaining('엄마 · ').first);
    await t.pumpAndSettle();
    expect(find.textContaining(store.kid.who == '아빠' ? 'ESTP' : 'ISTJ'), findsWidgets);
    await t.tap(find.byKey(const Key('sample-close')));
    await t.pumpAndSettle();
    expect(store.demo, isNull);
    expect(store.kids.length, 1);
    expect(store.kid.name, '');
    expect(store.kid.recs.values.every((r) => !r.hasAny), true);
    expect(find.text('시작하기'), findsOneWidget);
    tab.value = 2;
    await t.pumpAndSettle();
    expect(find.text('함께 보기'), findsOneWidget);
    expect(find.text('원더휠 WonderWheel'), findsOneWidget);
    expect(find.text('받은 링크 열기'), findsNothing);
    expect(find.text('개인정보처리방침'), findsNothing);
    await t.tap(find.text('양육자 초대'));
    await t.pumpAndSettle();
    expect(find.text('카카오톡'), findsOneWidget);
  });

  testWidgets('아이 추가를 그만두면 빈 아이가 남지 않는다', (t) async {
    await boot(t, const Size(390, 844));
    store.setInfo(name: '콩이');
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

  testWidgets('오늘 탭: 미션 해 보고 스티커 받기 · 약속 적고 지키기 · 상황 카드 (360x640)', (t) async {
    await boot(t, const Size(360, 640));
    store.setInfo(name: '콩이');
    for (final it in C.items) {
      store.answer(it, 5);
    }
    await t.pumpAndSettle();
    await t.tap(find.text('오늘'));
    await t.pumpAndSettle();
    expect(tab.value, 3);
    expect(find.text('엄마·아빠 스티커판'), findsOneWidget);
    expect(find.textContaining('콩이에게 맞춘 미션'), findsOneWidget);
    // 다른 미션으로 바꾸면 글이 바뀐다
    final before = daily.mission(store.kid, today0).$1;
    await t.tap(find.text('다른 미션'));
    await t.pumpAndSettle();
    expect(daily.mission(store.kid, today0).$1, isNot(before));
    await t.tap(find.text('해 봤어요'));
    await t.pumpAndSettle();
    await t.tap(find.text('잘 통했어요'));
    await t.tap(find.text('다음: 스티커 고르기'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('sticker-${score(store.kid.cur.ans).code}')));
    await t.pumpAndSettle();
    expect(daily.streak(store.kid), 1);
    expect(find.text('오늘 스티커를 받았어요'), findsOneWidget);

    // 약속 적기 → 지키기
    await t.tap(find.text('약속·일정'));
    await t.pump(const Duration(seconds: 5)); // 알림 글(toast)이 사라질 때까지
    await t.pumpAndSettle();
    await t.tap(find.text('+ 약속·일정 적기'));
    await t.pumpAndSettle();
    await t.tap(find.text('놀이터 가기'));
    await t.pump();
    await t.ensureVisible(find.text('저장'));
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(daily.plansOf(store.kid).length, 1);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await t.tap(find.text('놀이터 가기'));
    await t.pumpAndSettle();
    expect(find.textContaining('미리 알려 주기'), findsOneWidget);
    await t.ensureVisible(find.text('약속 지켰어요'));
    await t.tap(find.text('약속 지켰어요'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('sticker-${score(store.kid.cur.ans).code}')));
    await t.pumpAndSettle();
    expect(daily.plansOf(store.kid).first.done, true);
    expect(daily.stickers(store.kid), 2);

    // 상황 카드
    await t.tap(find.text('상황 카드'));
    await t.pumpAndSettle();
    await t.tap(find.text(D.situations.first.t));
    await t.pumpAndSettle();
    expect(find.textContaining('콩이에게'), findsWidgets);
    expect(find.textContaining('이렇게 말해 보세요'), findsWidgets);
  });

  testWidgets('리포트 형제 탭: 두 아이 궁합, 놀이·부딪히는 상황·칭찬 (360x640)', (t) async {
    await boot(t, const Size(360, 640));
    store.setInfo(name: '콩이');
    for (final it in C.items) {
      store.answer(it, 5);
    }
    store.addKid();
    store.setInfo(name: '별이');
    for (final it in C.items) {
      store.answer(it, 1);
    }
    await t.pumpAndSettle();
    tab.value = 1;
    await t.pumpAndSettle();
    await t.tap(find.text('형제'));
    await t.pumpAndSettle();
    expect(find.text('정반대 짝꿍'), findsOneWidget);
    expect(find.text('다름'), findsNWidgets(4));
    for (final title in ['잘 맞는 점과 함께할 놀이', '자주 부딪히는 상황', '아이마다 다르게 칭찬하기']) {
      final row = find.ancestor(of: find.text(title), matching: find.byType(Row)).first;
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: row, matching: find.byType(MoreBtn)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('back')), findsOneWidget);
      if (title == '자주 부딪히는 상황') {
        await t.ensureVisible(find.text('형제·자매가 다툴 때'));
        await t.tap(find.text('형제·자매가 다툴 때'));
        await t.pumpAndSettle();
        expect(find.textContaining('이렇게 말해 보세요'), findsWidgets);
        await t.tap(find.byKey(const Key('popup-close')));
        await t.pumpAndSettle();
      }
      if (title == '아이마다 다르게 칭찬하기') expect(find.textContaining('별이에게'), findsWidgets);
      await t.tap(find.byKey(const Key('back')));
      await t.pumpAndSettle();
    }
  });
}
