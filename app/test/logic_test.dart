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
}
