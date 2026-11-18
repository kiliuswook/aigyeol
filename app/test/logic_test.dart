import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:childmbti/content.dart';
import 'package:childmbti/scoring.dart';
import 'package:childmbti/store.dart';

void main() {
  setUpAll(() => C = Content.fromString(File('assets/data/content.json').readAsStringSync()));

  test('채점이 웹 시제품과 같다', () {
    final v = jsonDecode(File('test/web_vectors.json').readAsStringSync());
    for (final c in v['cases']) {
      final ans = {for (final e in (c['ans'] as Map).entries) e.key as String: e.value as int};
      final r = score(ans);
      expect(r.code, c['code']);
      expect(r.ax.map((x) => x.sc).toList(), c['ax']);
      expect([for (final x in r.ax) x.subs], c['subs']);
      expect(r.gr.map((x) => x.sc).toList(), c['gr']);
      expect(r.cons, c['cons']);
      expect(r.unk, c['unk']);
    }
  });

  test('링크 인코딩이 웹과 같다', () {
    final v = jsonDecode(File('test/web_vectors.json').readAsStringSync());
    expect(Store.b64e({'k': 'abc', 'n': '콩이', 'a': '만 5세', 'f': '엄마', 'w': '아빠', 'p': 1, 'o': 'x1'}), v['link']);
    final ans = {for (final e in (v['cases'][0]['ans'] as Map).entries) e.key as String: e.value as int};
    expect(Store.encA(ans), v['encA']);
    expect(Store.decA(Store.encA(ans)), ans);
    expect(Store.b64d(v['link'])!['n'], '콩이');
  });

  test('가격: 아이마다 첫 검사 1달러, 그 뒤 0.5달러, 새 아이는 다시 1달러', () {
    final s = Store();
    expect(s.kid.nextPrice, Price.first);
    s.buy(false);
    expect(s.kid.nextPrice, Price.more);
    s.setWho('아빠');
    expect(s.payKind(false), 'cg');
    s.addKid();
    expect(s.kid.nextPrice, Price.first);
    expect(Price.fmt(Price.first), r'$1');
    expect(Price.fmt(Price.more), r'$0.50');
  });

  test('다시 검사하기는 이전 기록을 남기고 답을 지운다', () {
    final s = Store();
    s.sample();
    final code = score(s.cur.ans).code;
    s.cur.prev = null;
    s.buy(true);
    expect(s.cur.prev!.code, code);
    expect(s.cur.ans, isEmpty);
    expect(s.kid.buys.last.kind, 'retest');
  });

  test('초대 받기 → 결과 보내기 → 합치기', () {
    final mom = Store();
    mom.setInfo(name: '콩이');
    mom.buy(false);
    final inv = Store.b64d(mom.inviteUrl('아빠').split('#i=')[1])!;
    final dad = Store();
    dad.joinInvite(inv, '아빠');
    expect(dad.kid.key, mom.kid.key);
    expect(dad.kid.nextPrice, Price.more);
    expect(dad.kid.who, '아빠');
    dad.genAns(C.items, {'A': 4, 'B': 2, 'C': 4, 'D': 2}, 3, dad.cur.ans);
    final res = Store.b64d(dad.backUrl().split('#c=')[1])!;
    mom.mergeResult(res);
    expect(mom.kid.recs['아빠']!.recv, true);
    expect(fullDone(mom.kid.recs['아빠']!.ans), true);
  });

  test('기록 파일: 앱 형식 왕복, 웹 시제품 형식 불러오기', () {
    final a = Store();
    a.sample();
    a.addKid(name: '둘째');
    final b = Store();
    expect(b.importBackup(a.exportBackup()), true);
    expect(b.kids.length, 2);
    final web = jsonEncode({
      'app': 'aigyeol', 'v': 1,
      'st': {'kid': 'k1', 'korder': ['k1', 'k2'], 'name': '콩이', 'who': '엄마', 'ans': {'A0-0': 4}, 'paid': 1, 'buys': [], 'pass': {'start': 1},
        'cgs': {'아빠': {'ans': {'A0-0': 2}, 'paid': 1}}, 'kids': {'k2': {'name': '둘째', 'who': '엄마', 'ans': {}, 'cgs': {}, 'buys': []}}},
    });
    final c = Store();
    expect(c.importBackup(web), true);
    expect(c.kids.map((k) => k.name).toList(), ['콩이', '둘째']);
    expect(c.kid.recs['아빠']!.ans['A0-0'], 2);
    expect(c.kid.nextPrice, Price.more);
  });

  test('받은 링크 읽기: # 뒤와 예전 ? 모두', () {
    // links.dart 의 Landing 은 UI 파일이라 여기서는 형식만 확인
    expect(Uri.splitQueryString('t=ENFP')['t'], 'ENFP');
  });

  test('동기화 합치기: 같은 아이는 최근 기록, 결제 합침, 새 아이 추가', () {
    final a = Store(), b = Store();
    a.kids.first.name = '콩이';
    a.buy(false);
    for (final it in C.items.take(10)) {
      a.answer(it, 3);
    }
    // 다른 폰(b): 같은 아이를 서버에서 받은 뒤 아빠가 검사, 그리고 동생 추가
    b.mergeFrom(jsonDecode(jsonEncode(a.toJson())));
    expect(b.kids.length, 1);
    expect(b.kid.name, '콩이');
    b.setWho('아빠');
    b.buy(false);
    for (final it in C.items) {
      b.answer(it, 4);
    }
    b.addKid(name: '동동');
    // a 는 그 사이 엄마 답을 더 함
    for (final it in C.items.skip(10).take(5)) {
      a.answer(it, 2);
    }
    a.mergeFrom(jsonDecode(jsonEncode(b.toJson())));
    expect(a.kids.length, 2);
    final k = a.kids.firstWhere((x) => x.name == '콩이');
    expect(k.buys.length, 2);
    expect(k.recs['엄마']!.ans.length, 15);
    expect(k.recs['아빠']!.ans.length, C.items.length);
    // 다시 검사하기로 답을 지운 기록이 예전 전체 기록보다 최근이면 그대로 남는다
    final c = Store()..mergeFrom(jsonDecode(jsonEncode(a.toJson())));
    c.setKid(c.kids.firstWhere((x) => x.name == '콩이').id);
    c.setWho('아빠');
    c.buy(true);
    a.mergeFrom(jsonDecode(jsonEncode(c.toJson())));
    final r = a.kids.firstWhere((x) => x.name == '콩이').recs['아빠']!;
    expect(r.ans.isEmpty, true);
    expect(r.prev, isNotNull);
  });
  test('태어난 해·달로 만 나이를 센다', () {
    final now = DateTime(2026, 11, 19);
    expect(ageOf('2021-03', now), ('만 5세', '만 5세 8개월'));
    expect(ageOf('2021-11', now), ('만 5세', '만 5세'));
    expect(ageOf('2021-12', now), ('만 4세', '만 4세 11개월'));
    expect(ageOf('2021-', now), ('', ''));
    final k = Kid.fromJson(Kid(birth: '2020-01').toJson());
    expect(k.birth, '2020-01');
    expect(k.age, startsWith('만 '));
  });
}
