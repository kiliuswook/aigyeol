// 앱 상태: 자녀, 양육자별 기록, 결제 기록. 웹(index.html)과 같은 규칙이지만 바꿔 끼우기 없이 아이마다 기록을 그대로 둔다.
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content.dart';
import 'scoring.dart';

/// 가격(바꿀 때는 이곳만). first: 아이마다 첫 정밀검사, more: 그 아이의 다른 양육자 검사·다시 검사하기.
/// 실제 결제는 구글 플레이 인앱 상품(소모성) 두 개로 연결하고, 화면 가격은 플레이가 주는 현지 가격으로 바꾼다.
class Price {
  static const first = 1.0, more = 0.5;
  static const skuFirst = 'test_first', skuMore = 'test_more';
  static String fmt(double p) => '\$${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(2)}';
}

/// 공유·초대·결과 링크에 쓰는 앱 웹 주소(웹 index.html 의 SITE 와 같게)
const kSite = 'https://childmbti.wonderwheel.co.kr/';
const kCgl = ['엄마', '아빠', '할머니', '할아버지', '기타 양육자'];

final _rnd = Random();
String rid() => DateTime.now().millisecondsSinceEpoch.toRadixString(36) + _rnd.nextInt(1 << 30).toRadixString(36);
String today([int dd = 0]) {
  final d = DateTime.now().add(Duration(days: dd));
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

Ans _ans(dynamic j) => j is Map ? {for (final e in j.entries) '${e.key}': (e.value as num).round()} : {};

/// 양육자 한 사람의 기록
class Rec {
  Ans ans;
  String date;
  bool paid, recv, sample;
  Snap? prev;
  /// 마지막으로 바뀐 때(ms). 기기 사이 동기화에서 더 최근 기록을 고르는 데 쓴다.
  int t;
  Rec({Ans? ans, this.date = '', this.paid = false, this.prev, this.recv = false, this.sample = false, this.t = 0}) : ans = ans ?? {};
  void touch() => t = DateTime.now().millisecondsSinceEpoch;
  bool get hasAny => ans.isNotEmpty || prev != null || paid;
  Map<String, dynamic> toJson() => {'ans': ans, 'date': date, 'paid': paid, if (prev != null) 'prev': prev!.toJson(), if (recv) 'recv': true, if (sample) 'sample': true, if (t > 0) 't': t};
  factory Rec.fromJson(dynamic j) => Rec(
      ans: _ans(j['ans']), date: '${j['date'] ?? ''}', paid: j['paid'] == true || j['paid'] == 1,
      prev: Snap.fromJson(j['prev']), recv: j['recv'] == true || j['recv'] == 1, sample: j['sample'] == true || j['sample'] == 1, t: (j['t'] as num?)?.round() ?? 0);
}

class Buy {
  final String id, kind, who;
  final int t;
  final double price;
  Buy(this.id, this.t, this.kind, this.who, this.price);
  Map<String, dynamic> toJson() => {'id': id, 't': t, 'kind': kind, 'who': who, 'price': price};
  factory Buy.fromJson(dynamic j) => Buy('${j['id'] ?? ''}', (j['t'] as num?)?.round() ?? 0, '${j['kind'] ?? 'first'}', '${j['who'] ?? ''}', (j['price'] as num?)?.toDouble() ?? 0);
}

/// 아이 한 명. key: 기기 사이에서 같은 아이를 알아보는 무작위 값(초대·결과 링크에 실림).
/// ext: 다른 휴대폰에서 첫 검사를 결제한 아이(초대로 받은 아이) {o: 첫 결제 번호, from}. inv: 받은 초대 {from}
class Kid {
  String id, key, name, age, who;
  Map<String, Rec> recs;
  List<Buy> buys;
  Map<String, dynamic>? ext, inv;
  Kid({String? id, String? key, this.name = '', this.age = '', this.who = '엄마', Map<String, Rec>? recs, List<Buy>? buys, this.ext, this.inv})
      : id = id ?? 'k${rid()}', key = key ?? rid(), recs = recs ?? {}, buys = buys ?? [];
  Rec get cur => recs.putIfAbsent(who, () => Rec());
  bool get firstDone => buys.isNotEmpty || ext != null;
  double get nextPrice => firstDone ? Price.more : Price.first;
  String firstBuyId() => buys.isNotEmpty ? buys.first.id : '${ext?['o'] ?? ''}';
  String label(int i) => name.isNotEmpty ? name : '아이 ${i + 1}';
  bool get isBlank => name.isEmpty && recs.values.every((r) => !r.hasAny) && buys.isEmpty;

  /// 고를 수 있는 양육자 이름(기본 목록 + 기록이 있는 사람)
  List<String> get names => {...kCgl, who, ...recs.keys}.toList();

  /// 기록이 있는 양육자들(지금 양육자는 늘 포함)
  List<MapEntry<String, Rec>> get cgs => [
        for (final n in names)
          if (n == who) MapEntry(n, cur) else if (recs[n]?.hasAny ?? false) MapEntry(n, recs[n]!)
      ];

  Map<String, dynamic> toJson() => {
        'id': id, 'key': key, 'name': name, 'age': age, 'who': who,
        'recs': {for (final e in recs.entries) if (e.value.hasAny || e.key == who) e.key: e.value.toJson()},
        'buys': [for (final b in buys) b.toJson()], if (ext != null) 'ext': ext, if (inv != null) 'inv': inv,
      };
  factory Kid.fromJson(dynamic j) => Kid(
        id: j['id'], key: j['key'], name: '${j['name'] ?? ''}', age: '${j['age'] ?? ''}', who: '${j['who'] ?? '엄마'}',
        recs: {for (final e in ((j['recs'] ?? {}) as Map).entries) '${e.key}': Rec.fromJson(e.value)},
        buys: [for (final b in (j['buys'] ?? []) as List) Buy.fromJson(b)],
        ext: (j['ext'] as Map?)?.cast<String, dynamic>(), inv: (j['inv'] as Map?)?.cast<String, dynamic>(),
      );

  /// 웹 시제품 기록(바꿔 끼우는 형식)의 아이 하나를 옮긴다
  factory Kid.fromWeb(Map j, String id) {
    final who = '${j['who'] ?? '엄마'}';
    final recs = <String, Rec>{};
    for (final e in ((j['cgs'] ?? {}) as Map).entries) {
      final c = e.value as Map;
      recs['${e.key}'] = Rec(ans: _ans(c['ans']), date: '${c['date'] ?? ''}', paid: c['paid'] == 1 || c['paid'] == true, prev: Snap.fromJson(c['prev']), recv: c['recv'] == 1, sample: c['sample'] == 1);
    }
    recs[who] = Rec(ans: _ans(j['ans']), date: '${j['date'] ?? ''}', paid: j['paid'] == 1 || j['paid'] == true || j['pass'] != null, prev: Snap.fromJson(j['prev']));
    final buys = [for (final b in (j['buys'] ?? []) as List) Buy.fromJson(b)];
    if (buys.isEmpty && j['pass'] != null) buys.add(Buy(rid(), 0, 'first', who, 0));
    final ext = j['ext'];
    return Kid(
        id: id, key: j['key'] ?? rid(), name: '${j['name'] ?? ''}', age: '${j['age'] ?? ''}', who: who, recs: recs, buys: buys,
        ext: ext is Map ? ext.cast<String, dynamic>() : (ext == 1 || ext == true) ? {'o': ''} : null,
        inv: (j['inv'] as Map?)?.cast<String, dynamic>());
  }
}

class Store extends ChangeNotifier {
  static const _k = 'childmbti';
  List<Kid> kids = [Kid()];
  String kidId = '';
  SharedPreferences? _sp;

  Kid get kid => kids.firstWhere((k) => k.id == kidId, orElse: () => kids.first);
  Rec get cur => kid.cur;
  String get nm => kid.name.isNotEmpty ? kid.name : '우리 아이';

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    final s = _sp!.getString(_k);
    if (s != null) {
      try {
        fromJson(jsonDecode(s));
      } catch (_) {}
    }
    if (kidId.isEmpty) kidId = kids.first.id;
  }

  /// 저장할 때마다 부르는 곳(로그인했으면 서버로 동기화)
  void Function()? onSaved;

  void save() {
    _sp?.setString(_k, jsonEncode(toJson()));
    notifyListeners();
    onSaved?.call();
  }

  Map<String, dynamic> toJson() => {'v': 2, 'kid': kidId, 'kids': [for (final k in kids) k.toJson()]};
  void fromJson(Map j) {
    final ks = [for (final k in (j['kids'] ?? []) as List) Kid.fromJson(k)];
    if (ks.isEmpty) return;
    kids = ks;
    kidId = '${j['kid'] ?? ks.first.id}';
  }

  /// 기록 파일(백업) 불러오기: 앱 형식(v2)과 웹 시제품 형식(v1) 모두
  bool importBackup(String text) {
    try {
      final d = jsonDecode(text);
      if (d is! Map || d['app'] != 'aigyeol') return false;
      if (d['v'] == 2 && d['data'] is Map) {
        fromJson(d['data']);
      } else if (d['st'] is Map) {
        final st = d['st'] as Map;
        final order = [for (final x in (st['korder'] ?? [st['kid'] ?? 'k1']) as List) '$x'];
        final active = '${st['kid'] ?? 'k1'}';
        kids = [
          for (final id in order)
            if (id == active) Kid.fromWeb(st, id) else if ((st['kids'] ?? {})[id] is Map) Kid.fromWeb(st['kids'][id], id)
        ];
        if (kids.isEmpty) kids = [Kid.fromWeb(st, active)];
        kidId = active;
      } else {
        return false;
      }
      save();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 다른 기기(서버)의 기록과 합치기. 같은 아이(key)는 양육자별로 더 최근(같은 날이면 답이 더 많은) 기록을 남기고, 결제 기록은 합친다.
  void mergeFrom(Map j) {
    final remote = [for (final k in (j['kids'] ?? []) as List) Kid.fromJson(k)];
    if (remote.isEmpty) return;
    if (kids.length == 1 && kids.first.isBlank) kids = [];
    for (final r in remote) {
      final l = kidByKey(r.key);
      if (l == null) {
        kids.add(r);
        continue;
      }
      if (l.name.isEmpty) l.name = r.name;
      if (l.age.isEmpty) l.age = r.age;
      l.ext ??= r.ext;
      l.inv ??= r.inv;
      final ids = {for (final b in l.buys) b.id};
      l.buys.addAll(r.buys.where((b) => !ids.contains(b.id)));
      l.buys.sort((a, b) => a.t.compareTo(b.t));
      for (final e in r.recs.entries) {
        final mine = l.recs[e.key], o = e.value;
        if (mine == null || !mine.hasAny) {
          l.recs[e.key] = o;
          continue;
        }
        final dc = o.t != mine.t ? o.t.compareTo(mine.t) : o.date.compareTo(mine.date);
        final better = dc > 0 || (dc == 0 && o.ans.length > mine.ans.length);
        final keep = better ? o : mine, other = better ? mine : o;
        keep.prev ??= other.prev;
        keep.paid = keep.paid || other.paid;
        l.recs[e.key] = keep;
      }
    }
    if (kids.isEmpty) kids = [Kid()];
    if (!kids.any((k) => k.id == kidId)) kidId = kids.first.id;
    save();
  }

  String exportBackup() => jsonEncode({'app': 'aigyeol', 'v': 2, 'at': DateTime.now().millisecondsSinceEpoch, 'data': toJson()});

  // ---------- 자녀 ----------
  void setKid(String id) {
    kidId = id;
    save();
  }

  Kid addKid({String? key, String name = '', String age = ''}) {
    final k = Kid(key: key, name: name, age: age, who: kid.who);
    kids.add(k);
    kidId = k.id;
    save();
    return k;
  }

  Kid? kidByKey(String key) => kids.where((k) => k.key == key).firstOrNull;

  void setInfo({String? name, String? age}) {
    if (name != null) kid.name = name.trim();
    if (age != null) kid.age = age;
    save();
  }

  void setWho(String n) {
    if (n.isEmpty || n == kid.who) return;
    kid.who = n;
    save();
  }

  // ---------- 검사 ----------
  void answer(Item it, int a) {
    cur.ans[it.id] = a;
    cur.date = today();
    cur.touch();
    save();
  }

  /// 결제 종류: 'retest' 다시 검사하기, 'cg' 양육자 추가 검사, 'first' 아이의 첫 검사
  String payKind(bool retest) => retest ? 'retest' : kid.firstDone ? 'cg' : 'first';

  /// 결제(시제품은 바로 열림). 다시 검사하기면 지금 결과를 이전 기록으로 남기고 답을 지운다.
  void buy(bool retest) {
    final k = payKind(retest), p = kid.nextPrice;
    kid.buys.add(Buy(rid(), DateTime.now().millisecondsSinceEpoch, k, kid.who, p));
    if (k == 'retest') {
      cur.prev = Snap.of(cur.ans, cur.date, kid.who);
      cur.ans = {};
      cur.date = today();
    }
    cur.paid = true;
    cur.touch();
    save();
  }

  void resetKid() {
    kid.recs = {};
    kid.buys = [];
    kid.ext = null;
    kid.inv = null;
    save();
  }

  // ---------- 샘플 리포트 ----------
  Ans genAns(Iterable<Item> list, Map<String, int> base, int g, [Ans? into]) {
    const seed = [4, 5, 2, 4, 3, 5, 2, 4, 1, 5, 4, 2, 5, 3];
    var k = 0;
    final o = into ?? {};
    for (final it in list) {
      final b = it.ax != null ? base[it.ax]! : g;
      final s = seed[k++ % seed.length];
      var a = b + (s > 3 ? 0 : (k % 2 == 1 ? 1 : -1));
      a = a.clamp(1, 5);
      o[it.id] = it.r ? 6 - a : a;
    }
    return o;
  }

  void sample() {
    final c = cur;
    genAns(C.items, {'A': 2, 'B': 4, 'C': 2, 'D': 4}, 4, c.ans);
    if (kid.name.isEmpty) kid.name = '콩이';
    if (kid.age.isEmpty) kid.age = '만 5세';
    c.date = today();
    c.paid = true;
    if (c.prev == null) {
      final pa = genAns(C.items.where((x) => x.ax == 'D'), {'D': 2}, 0, Map.of(c.ans));
      for (final x in C.items.where((x) => x.gr == 'G1')) {
        pa[x.id] = x.r ? min(5, pa[x.id]! + 1) : max(1, pa[x.id]! - 1);
      }
      for (final x in C.items.where((x) => x.gr == 'G3').take(4)) {
        pa[x.id] = 0;
      }
      c.prev = Snap.of(pa, today(-60), kid.who, sample: true);
    }
    if (!kid.cgs.any((e) => e.key != kid.who && fullDone(e.value.ans))) {
      final other = kCgl.where((n) => n != kid.who && !(kid.recs[n]?.hasAny ?? false)).firstOrNull;
      if (other != null) {
        kid.recs[other] = Rec(ans: genAns(C.items, {'A': 4, 'B': 4, 'C': 2, 'D': 3}, 3), date: today(), paid: true, sample: true);
      }
    }
    save();
  }

  // ---------- 공유 링크 ----------
  static String b64e(Map o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  static Map? b64d(String s) {
    try {
      s = s.replaceAll('-', '+').replaceAll('_', '/');
      while (s.length % 4 != 0) {
        s += '=';
      }
      final d = jsonDecode(utf8.decode(base64.decode(s)));
      return d is Map ? d : null;
    } catch (_) {
      return null;
    }
  }

  static String encA(Ans ans) => C.items.map((x) => ans[x.id] == null ? '-' : '${ans[x.id]}').join();
  static Ans decA(String s) => {
        for (var i = 0; i < C.items.length && i < s.length; i++)
          if ('012345'.contains(s[i])) C.items[i].id: int.parse(s[i])
      };

  String inviteUrl(String role) => '$kSite#i=${b64e({'k': kid.key, 'n': kid.name, 'a': kid.age, 'f': kid.who, 'w': role, 'p': kid.firstDone ? 1 : 0, 'o': kid.firstBuyId()})}';
  String backUrl() => '$kSite#c=${b64e({'k': kid.key, 'n': kid.name, 'a': kid.age, 'w': kid.who, 'd': cur.date, 'x': encA(cur.ans)})}';
  static String typeUrl(String code) => '$kSite#t=$code';
  static const appUrl = '$kSite#r=app';

  /// 초대 받기: 같은 아이(key)가 있으면 그 아이로, 없으면 새 아이로. 고른 역할로 검사를 시작할 수 있게 한다.
  void joinInvite(Map d, String role) {
    final k = kidByKey('${d['k']}');
    if (k != null) {
      kidId = k.id;
    } else if (kids.length == 1 && kids.first.isBlank) {
      kids.first.key = '${d['k']}';
    } else {
      addKid(key: '${d['k']}');
    }
    final n = '${d['n'] ?? ''}', a = '${d['a'] ?? ''}';
    if (n.isNotEmpty && kid.name.isEmpty) kid.name = n;
    if (a.isNotEmpty && kid.age.isEmpty) kid.age = a;
    if (d['p'] == 1) kid.ext = {'o': '${d['o'] ?? ''}', 'from': '${d['f'] ?? ''}'};
    kid.inv = {'from': '${d['f'] ?? ''}', 'at': DateTime.now().millisecondsSinceEpoch};
    kid.who = role;
    save();
  }

  /// 결과 받기: 같은 아이의 그 양육자 결과로 합친다.
  void mergeResult(Map d) {
    final k = kidByKey('${d['k']}');
    if (k != null) {
      kidId = k.id;
    } else {
      addKid(key: '${d['k']}', name: '${d['n'] ?? ''}', age: '${d['a'] ?? ''}');
    }
    var w = '${d['w'] ?? '가족'}';
    final rec = Rec(ans: decA('${d['x'] ?? ''}'), date: '${d['d'] ?? today()}', paid: true, recv: true);
    final mine = cur;
    if (w == kid.who && (mine.ans.isNotEmpty || mine.prev != null)) w = '$w(받은 결과)';
    kid.recs[w] = rec;
    if (mine.ans.isEmpty && mine.prev == null) kid.who = w;
    save();
  }
}

final store = Store();
