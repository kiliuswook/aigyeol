// 문항·유형 풀이 데이터. assets/data/content.json 은 웹(index.html)의 AX, GR, P, NICK, OPT, EXS 에서 뽑았다.
import 'dart:convert';
import 'package:flutter/services.dart';

class Sub {
  final String n, lo, hi;
  Sub(Map j) : n = j['n'], lo = j['lo'], hi = j['hi'];
}

class Ax {
  final String id, h, l, hi, lo, q, c;
  final List<Sub> subs;
  Ax(Map j)
      : id = j['id'], h = j['H'], l = j['L'], hi = j['hi'], lo = j['lo'], q = j['q'],
        c = (j['c'] as String).replaceAll('--', ''),
        subs = [for (final s in j['subs']) Sub(s)];
  Color get color => kColors[c]!;
}

class Grow {
  final String id, n, d;
  final List<List<String>> lv; // 0 지금 자라는 중, 1 고르게 자라는 중, 2 탄탄함: [요약, 상세]
  final int count;
  Grow(Map j)
      : id = j['id'], n = j['n'], d = j['d'], count = j['count'],
        lv = [for (final x in j['lv']) List<String>.from(x)];
}

class Pole {
  final List<String> tags;
  final String sum, det, st, wa, say, no, ph;
  /// 상황별 말 예시 4가지: [상황, 이렇게 말해 보세요]
  final List<List<String>> says;
  Pole(Map j)
      : tags = List<String>.from(j['tags']), sum = j['sum'], det = j['det'], st = j['st'],
        wa = j['wa'], say = j['say'], no = j['no'], ph = j['ph'],
        says = [for (final x in (j['says'] ?? const [])) List<String>.from(x)];
}

class Item {
  final String id, t, ex;
  final String? ax, gr;
  final int? sub;
  final bool r; // 역채점
  Item(Map j)
      : id = j['id'], t = j['t'], ex = j['ex'], ax = j['ax'], gr = j['gr'], sub = j['sub'], r = j['r'] == 1;
}

class Content {
  final List<Ax> axes;
  final List<Grow> grows;
  final Map<String, Pole> poles;
  final Map<String, String> nick;
  final List<String> opt;
  final List<Item> items;
  Content(Map j)
      : axes = [for (final a in j['axes']) Ax(a)],
        grows = [for (final g in j['grows']) Grow(g)],
        poles = {for (final e in (j['poles'] as Map).entries) e.key as String: Pole(e.value)},
        nick = Map<String, String>.from(j['nick']),
        opt = List<String>.from(j['opt']),
        items = [for (final i in j['items']) Item(i)];

  /// 세부 기질 하나(4문항) 또는 자라는 힘 하나(6문항)씩 묶은 문항 묶음. 응답 일관성 계산에 쓴다.
  late final List<List<Item>> groups = [
    for (final a in axes)
      for (var si = 0; si < a.subs.length; si++) items.where((x) => x.ax == a.id && x.sub == si).toList(),
    for (final g in grows) items.where((x) => x.gr == g.id).toList(),
  ];

  static Content fromString(String s) => Content(jsonDecode(s));
}

late Content C;
Future<void> loadContent() async => C = Content.fromString(await rootBundle.loadString('assets/data/content.json'));

const kColors = {
  'c1': Color(0xFFDD7356),
  'c2': Color(0xFF3A9586),
  'c3': Color(0xFFCF6189),
  'c4': Color(0xFF4C7CC0),
  'g': Color(0xFF6A9F45),
};
