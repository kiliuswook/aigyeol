// 공유하기: 스토어 연결 링크, 가족 연결 코드, 결과 화면 그림 공유
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/fam.dart';
import 'package:childmbti/scoring.dart';
import 'package:childmbti/store.dart';
import 'package:childmbti/ui/links.dart';
import 'package:childmbti/ui/share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadContent);

  test('초대 코드: 형식 바꿔 읽기, 글 속에서 찾기', () {
    expect(Fam.norm('abcde-fgh23'), 'ABCDEFGH23');
    expect(Fam.norm('ABCDE FGH23'), 'ABCDEFGH23');
    expect(Fam.norm('ABCDE-FGH2O'), isNull); // O 는 쓰지 않는 글자
    expect(Fam.norm('ABCD'), isNull);
    expect(Fam.find('엄마가 초대했어요\n초대 코드 KQ7MZ-P3XWA · 앱을 설치한 뒤'), 'KQ7MZP3XWA');
    expect(Fam.find('코드 없음 HELLO'), isNull);
    expect(Fam.show('KQ7MZP3XWA'), 'KQ7MZ-P3XWA');
  });

  test('받은 링크 읽기: 앱 주소·설치 정보·연결 페이지', () {
    final a = Landing.parse('childmbti://open?f=KQ7MZP3XWA&w=%EC%95%84%EB%B9%A0')!;
    expect(a.kind, 'fam');
    expect(a.code, 'KQ7MZP3XWA');
    expect(a.role, '아빠');
    expect(Landing.parse('https://childmbti.wonderwheel.co.kr/go/#f=KQ7MZP3XWA')!.kind, 'fam');
    expect(Landing.parse('childmbti://open?t=ENFP')!.code, 'ENFP');
    expect(Landing.parse('childmbti://open?r=app')!.kind, 'app');
    // 플레이 기본 설치 정보(링크 없이 설치)는 무시
    expect(Landing.parse('childmbti://open?utm_source=google-play&utm_medium=organic'), isNull);
  });

  test('공유 주소는 모두 스토어 연결 페이지로', () {
    expect(Store.appUrl, 'https://childmbti.wonderwheel.co.kr/go/#r=app');
    expect(Store.typeUrl('ENFP'), 'https://childmbti.wonderwheel.co.kr/go/#t=ENFP');
    expect(Store.famUrl('KQ7MZP3XWA', '아빠'), 'https://childmbti.wonderwheel.co.kr/go/#f=KQ7MZP3XWA&w=%EC%95%84%EB%B9%A0');
  });

  test('가족 연결로 받은 결과: 넣기, 내 기록은 덮지 않기, 더 새 것만', () async {
    await loadContent();
    final k = Kid(who: '엄마');
    final mine = k.cur..ans = store.genAns(C.items, {'A': 2, 'B': 2, 'C': 2, 'D': 2}, 2);
    mine.t = 5;
    final dad = Rec(ans: store.genAns(C.items, {'A': 4, 'B': 4, 'C': 4, 'D': 4}, 4), paid: true, recv: true, t: 10);
    expect(store.putFamRec(k, '아빠', dad), isTrue);
    expect(fullDone(k.recs['아빠']!.ans), isTrue);
    // 더 오래된 것은 넣지 않음
    expect(store.putFamRec(k, '아빠', Rec(ans: {'x': 1}, recv: true, t: 3)), isFalse);
    // 이 휴대폰에서 직접 답한 '엄마'는 덮지 않음
    expect(store.putFamRec(k, '엄마', Rec(ans: {'x': 1}, recv: true, t: 99)), isFalse);
    expect(k.recs['엄마'], same(mine));
  });

  testWidgets('결과 공유 창: 결과 카드가 그림으로 찍힌다 (360x640)', (t) async {
    await t.runAsync(loadContent);
    await t.binding.setSurfaceSize(const Size(360, 640));
    store.kids = [Kid(name: '하늘')];
    store.kidId = store.kids.first.id;
    store.cur
      ..ans = store.genAns(C.items, {'A': 4, 'B': 2, 'C': 4, 'D': 2}, 3)
      ..paid = true;
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    shareResult(ctx);
    await t.pumpAndSettle();
    expect(find.byType(ResultCard), findsOneWidget);
    expect(find.text(score(store.cur.ans).code.substring(0, 1)), findsWidgets);
    // 이름 넣기
    await t.tap(find.text('아이 이름 넣기'));
    await t.pumpAndSettle();
    expect(find.text('하늘의 MBTI'), findsOneWidget);
    final key = (t.widget(find.ancestor(of: find.byType(ResultCard), matching: find.byType(RepaintBoundary)).first) as RepaintBoundary).key as GlobalKey;
    Uint8List? png;
    await t.runAsync(() async => png = await capture(key, pixelRatio: 2));
    expect(png, isNotNull);
    expect(png!.length, greaterThan(1000));
    expect(t.takeException(), isNull);
  });

  testWidgets('양육자 초대 창: 초대 코드가 보이고 코드 복사 버튼으로 복사된다 (360x640)', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 640));
    store.kids = [Kid(name: '하늘', fam: 'KQ7MZP3XWA')];
    store.kidId = store.kids.first.id;
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') copied = (c.arguments as Map)['text'];
      return null;
    });
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    inviteCg(ctx);
    await t.pumpAndSettle();
    expect(find.text('KQ7MZ-P3XWA'), findsOneWidget);
    await t.ensureVisible(find.text('코드 복사'));
    await t.tap(find.text('코드 복사'));
    await t.pumpAndSettle();
    expect(copied, 'KQ7MZ-P3XWA');
    expect(find.text('초대 코드를 복사했습니다.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
