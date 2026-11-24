// 앱 상태: 자녀, 양육자별 기록, 결제 기록. 웹(index.html)과 같은 규칙이지만 바꿔 끼우기 없이 아이마다 기록을 그대로 둔다.
import 'i18n.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content.dart';
import 'dev.dart';
import 'scoring.dart';

/// 예전 검사별 결제 가격(2026-11-20 부터 결제 대신 보상형 광고, ads.dart). 지난 기록(buys)을 읽을 때만 남겨 둔다.
class Price {
  static const first = 1.0, more = 0.5;
  static const skuFirst = 'test_first', skuMore = 'test_more';
  static String fmt(double p) => '\$${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(2)}';
}

/// 공유·초대·결과 링크에 쓰는 앱 웹 주소(웹 index.html 의 SITE 와 같게)
const kSite = 'https://childmbti.wonderwheel.co.kr/';

/// 공유 링크가 가는 곳: 기기에 맞는 스토어(안드로이드 구글 플레이, 아이폰 앱스토어)로 바로 보내는 연결 페이지(저장소 go/index.html).
/// 안드로이드는 앱이 있으면 앱을 열고, 없으면 플레이로 가며 링크 값을 설치 정보로 넘긴다(deeplink.dart).
const kGo = '${kSite}go/';
const kCgl = ['엄마', '아빠', '할머니', '할아버지', '기타 양육자'];

/// 이름을 직접 적는 양육자 칸. 적은 이름(예: 이모)이 그대로 양육자 이름이 된다(통계에서는 '기타 양육자'로 묶는다).
const kOtherCg = '기타 양육자';

final _rnd = Random();
String rid() => DateTime.now().millisecondsSinceEpoch.toRadixString(36) + _rnd.nextInt(1 << 30).toRadixString(36);
String today([int dd = 0]) {
  final d = DateTime.now().add(Duration(days: dd));
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

/// 태어난 해·달('YYYY-MM')로 만 나이를 센다. ('만 5세', '만 5세 3개월'). 달만 받으므로 생일이 든 달부터 한 살 더한다.
(String, String) ageOf(String birth, [DateTime? now]) {
  final p = birth.split('-'), y = int.tryParse(p[0]), m = p.length > 1 ? int.tryParse(p[1]) : null;
  if (y == null || m == null) return ('', '');
  final n = now ?? DateTime.now();
  final mo = (n.year - y) * 12 + (n.month - m);
  if (mo < 0) return ('', '');
  return ('만 ${mo ~/ 12}세', '만 ${mo ~/ 12}세${mo % 12 > 0 ? ' ${mo % 12}개월' : ''}');
}

Ans _ans(dynamic j) => j is Map ? {for (final e in j.entries) '${e.key}': (e.value as num).round()} : {};

/// 양육자 한 사람의 기록
class Rec {
  Ans ans;
  String date;
  bool paid, recv, sample;
  /// 통계에 이미 보낸 검사인지(같은 검사를 두 번 세지 않게)
  bool st;
  Snap? prev;
  /// 마지막으로 바뀐 때(ms). 기기 사이 동기화에서 더 최근 기록을 고르는 데 쓴다.
  int t;
  Rec({Ans? ans, this.date = '', this.paid = false, this.prev, this.recv = false, this.sample = false, this.st = false, this.t = 0}) : ans = ans ?? {};
  void touch() => t = DateTime.now().millisecondsSinceEpoch;
  bool get hasAny => ans.isNotEmpty || prev != null || paid;
  Map<String, dynamic> toJson() => {'ans': ans, 'date': date, 'paid': paid, if (prev != null) 'prev': prev!.toJson(), if (recv) 'recv': true, if (sample) 'sample': true, if (st) 'st': true, if (t > 0) 't': t};
  factory Rec.fromJson(dynamic j) => Rec(
      ans: _ans(j['ans']), date: '${j['date'] ?? ''}', paid: j['paid'] == true || j['paid'] == 1,
      prev: Snap.fromJson(j['prev']), recv: j['recv'] == true || j['recv'] == 1, sample: j['sample'] == true || j['sample'] == 1, st: j['st'] == true, t: (j['t'] as num?)?.round() ?? 0);
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
/// fam: 가족 연결 코드(서버 fam/{코드}). 같은 코드를 가진 휴대폰끼리 이 아이의 양육자별 결과가 자동으로 오간다(fam.dart).
class Kid {
  /// age: '만 5세' 같은 글(링크·예전 기록용). birth: 태어난 해와 달 'YYYY-MM'. birth 가 있으면 age 는 거기서 계산한다.
  /// sex: 'M' 남자아이, 'F' 여자아이, '' 아직 안 넣음(또래 평균을 고르는 데만 쓴다)
  String id, key, name, age, who, birth, sex, fam;
  Map<String, Rec> recs;
  List<Buy> buys;
  /// 성장 발달 체크 기록(오래된 것부터). dev.dart
  List<DevRec> devs;
  Map<String, dynamic>? ext, inv;
  Kid({String? id, String? key, this.name = '', this.age = '', this.birth = '', this.sex = '', this.fam = '', this.who = '엄마', Map<String, Rec>? recs, List<Buy>? buys, List<DevRec>? devs, this.ext, this.inv})
      : id = id ?? 'k${rid()}', key = key ?? rid(), recs = recs ?? {}, buys = buys ?? [], devs = devs ?? [] {
    if (ageOf(birth).$1.isNotEmpty) age = ageOf(birth).$1;
  }

  /// 화면에 보여 줄 나이: 생년월이 있으면 '만 5세 3개월', 없으면 예전에 고른 연령
  String get ageText => ageOf(birth).$2.isNotEmpty ? ageOf(birth).$2 : age;
  Rec get cur => recs.putIfAbsent(who, () => Rec());
  bool get firstDone => buys.isNotEmpty || ext != null;
  double get nextPrice => firstDone ? Price.more : Price.first;
  String firstBuyId() => buys.isNotEmpty ? buys.first.id : '${ext?['o'] ?? ''}';
  String label(int i) => name.isNotEmpty ? name : tr('아이 {0}', [i + 1]);
  bool get isBlank => name.isEmpty && recs.values.every((r) => !r.hasAny) && buys.isEmpty && devs.isEmpty;

  /// 마지막으로 끝낸 발달 체크, 하다 만 체크
  DevRec? get devLast => devs.where((r) => r.done).lastOrNull;
  DevRec? get devOpen => devs.where((r) => !r.done).lastOrNull;

  /// 고를 수 있는 양육자 이름(기본 목록 + 기록이 있는 사람)
  List<String> get names => {...kCgl, who, ...recs.keys}.toList();

  /// 기록이 있는 양육자들(지금 양육자는 늘 포함)
  List<MapEntry<String, Rec>> get cgs => [
        for (final n in names)
          if (n == who) MapEntry(n, cur) else if (recs[n]?.hasAny ?? false) MapEntry(n, recs[n]!)
      ];

  Map<String, dynamic> toJson() => {
        'id': id, 'key': key, 'name': name, 'age': age, if (birth.isNotEmpty) 'birth': birth, if (sex.isNotEmpty) 'sex': sex, if (fam.isNotEmpty) 'fam': fam, 'who': who,
        'recs': {for (final e in recs.entries) if (e.value.hasAny || e.key == who) e.key: e.value.toJson()},
        'buys': [for (final b in buys) b.toJson()], if (devs.isNotEmpty) 'devs': [for (final r in devs) r.toJson()], if (ext != null) 'ext': ext, if (inv != null) 'inv': inv,
      };
  factory Kid.fromJson(dynamic j) => Kid(
        id: j['id'], key: j['key'], name: '${j['name'] ?? ''}', age: '${j['age'] ?? ''}', birth: '${j['birth'] ?? ''}', sex: j['sex'] == 'M' || j['sex'] == 'F' ? j['sex'] : '', fam: '${j['fam'] ?? ''}', who: '${j['who'] ?? '엄마'}',
        recs: {for (final e in ((j['recs'] ?? {}) as Map).entries) '${e.key}': Rec.fromJson(e.value)},
        buys: [for (final b in (j['buys'] ?? []) as List) Buy.fromJson(b)],
        devs: [for (final r in (j['devs'] ?? []) as List) DevRec.fromJson(r)],
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

  /// 샘플 리포트용 예시 아이. 있는 동안 화면은 이 아이를 보여 주지만 kids 에 넣지 않아 저장·동기화되지 않는다.
  Kid? demo;
  Kid get kid => demo ?? kids.firstWhere((k) => k.id == kidId, orElse: () => kids.first);
  Rec get cur => kid.cur;
  String get nm => kid.name.isNotEmpty ? kid.name : tr('우리 아이');

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    final s = _sp!.getString(_k);
    if (s != null) {
      try {
        fromJson(jsonDecode(s));
      } catch (_) {}
    }
    _dropSample();
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
      if (l.birth.isEmpty) l.birth = r.birth;
      if (l.sex.isEmpty) l.sex = r.sex;
      if (l.fam.isEmpty) l.fam = r.fam;
      l.ext ??= r.ext;
      l.inv ??= r.inv;
      final ids = {for (final b in l.buys) b.id};
      l.buys.addAll(r.buys.where((b) => !ids.contains(b.id)));
      l.buys.sort((a, b) => a.t.compareTo(b.t));
      l.devs = mergeDevs(l.devs, r.devs);
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
    _dropSample();
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

  /// 추가하다 그만둔 빈 아이를 지운다(아이가 하나뿐이면 그대로 둔다)
  void dropBlankKid(String id) {
    if (kids.length <= 1) return;
    final k = kids.where((k) => k.id == id).firstOrNull;
    if (k == null || !k.isBlank) return;
    kids.remove(k);
    if (kidId == id) kidId = kids.last.id;
    save();
  }

  Kid? kidByKey(String key) => kids.where((k) => k.key == key).firstOrNull;

  void setInfo({String? name, String? age, String? birth, String? sex}) {
    if (sex != null) kid.sex = sex;
    if (name != null) kid.name = name.trim();
    if (age != null) kid.age = age;
    if (birth != null) {
      kid.birth = birth;
      if (ageOf(birth).$1.isNotEmpty) kid.age = ageOf(birth).$1;
    }
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

  /// 검사 열기(보상형 광고를 본 뒤). 다시 검사하기면 지금 결과를 이전 기록으로 남기고 답을 지운다.
  void buy(bool retest) {
    final k = payKind(retest), p = 0.0; // 광고로 연 검사는 0원
    kid.buys.add(Buy(rid(), DateTime.now().millisecondsSinceEpoch, k, kid.who, p));
    if (k == 'retest') {
      cur.prev = Snap.of(cur.ans, cur.date, kid.who);
      cur.ans = {};
      cur.date = today();
      cur.st = false;
    }
    cur.paid = true;
    cur.touch();
    save();
  }

  // ---------- 성장 발달 체크 ----------
  /// 새 체크 시작(보상형 광고를 본 뒤). 지금 개월 수로 구간을 정한다. 하다 만 체크가 있으면 지우고 새로.
  DevRec? startDev() {
    final mo = monthsOf(kid.birth), b = mo == null ? null : devBand(mo);
    if (mo == null || b == null || (kid.sex != 'M' && kid.sex != 'F')) return null;
    kid.devs.removeWhere((r) => !r.done);
    final r = DevRec(date: today(), who: kid.who, sex: kid.sex, mo: mo, band: b)..touch();
    kid.devs.add(r);
    save();
    return r;
  }

  void devAnswer(DevRec r, String id, int a) {
    r.ans[id] = a;
    r.touch();
    save();
  }

  void devRegress(DevRec r, int v) {
    r.rg = v;
    r.date = today();
    r.touch();
    save();
  }

  /// 키·몸무게 넣기(빈 값은 지움). 이미 통계에 보낸 체크는 평균을 다시 세지 않는다.
  void devGrowth(DevRec r, double? h, double? w) {
    r.h = h;
    r.w = w;
    r.touch();
    save();
  }

  void devDelete(DevRec r) {
    kid.devs.remove(r);
    save();
  }

  void resetKid() {
    kid.devs = [];
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

  /// 샘플 리포트 열기: 예시 아이 '콩이'(엄마·아빠 검사, 지난 검사 기록 포함)를 만들어 잠시 보여 준다. 내 아이 기록은 건드리지 않는다.
  void openSample() {
    final k = Kid(name: tr('콩이'), age: '만 5세', sex: 'F', who: '엄마');
    final c = k.cur;
    genAns(C.items, {'A': 2, 'B': 4, 'C': 2, 'D': 4}, 4, c.ans);
    c.date = today();
    c.paid = true;
    final pa = genAns(C.items.where((x) => x.ax == 'D'), {'D': 2}, 0, Map.of(c.ans));
    for (final x in C.items.where((x) => x.gr == 'G1')) {
      pa[x.id] = x.r ? min(5, pa[x.id]! + 1) : max(1, pa[x.id]! - 1);
    }
    for (final x in C.items.where((x) => x.gr == 'G3').take(4)) {
      pa[x.id] = 0;
    }
    c.prev = Snap.of(pa, today(-60), k.who, sample: true);
    k.recs['아빠'] = Rec(ans: genAns(C.items, {'A': 4, 'B': 4, 'C': 2, 'D': 3}, 3), date: today(), paid: true, sample: true);
    demo = k;
    notifyListeners();
  }

  void closeSample() {
    if (demo == null) return;
    demo = null;
    notifyListeners();
  }

  /// 예전 버전은 샘플을 내 아이 기록에 써 넣었다. 그렇게 섞여 들어간 샘플 기록을 걷어 낸다.
  /// (실제 검사는 늘 결제 기록 buys 가 있고, 샘플은 없다)
  void _dropSample() {
    for (final k in kids) {
      if (k.buys.isNotEmpty || k.ext != null) {
        k.recs.removeWhere((n, r) => r.sample);
        continue;
      }
      final had = k.recs.values.any((r) => r.sample || (r.prev?.sample ?? false));
      if (!had) continue;
      k.recs.removeWhere((n, r) => r.sample || (r.prev?.sample ?? false));
      if (k.recs.values.every((r) => !r.hasAny)) {
        if (k.name == '콩이') k.name = '';
        if (k.age == '만 5세' && k.birth.isEmpty) k.age = '';
      }
    }
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

  String inviteUrl(String role) => '$kGo#i=${b64e({'k': kid.key, 'n': kid.name, 'a': kid.age, if (kid.birth.isNotEmpty) 'b': kid.birth, if (kid.sex.isNotEmpty) 's': kid.sex, 'f': kid.who, 'w': role, 'p': kid.firstDone ? 1 : 0, 'o': kid.firstBuyId()})}';
  String backUrl() => '$kGo#c=${b64e({'k': kid.key, 'n': kid.name, 'a': kid.age, 'w': kid.who, 'd': cur.date, 'x': encA(cur.ans)})}';
  static String typeUrl(String code) => '$kGo#t=$code';
  static const appUrl = '$kGo#r=app';
  /// 가족 연결 코드 초대. w: 초대한 사람이 고른 상대 역할(받는 화면에서 먼저 골라 둠)
  static String famUrl(String code, String role) => '$kGo#f=$code&w=${Uri.encodeComponent(role)}';

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
    final b = '${d['b'] ?? ''}', sx = '${d['s'] ?? ''}';
    if (ageOf(b).$1.isNotEmpty && kid.birth.isEmpty) kid.birth = b;
    if ((sx == 'M' || sx == 'F') && kid.sex.isEmpty) kid.sex = sx;
    if (d['p'] == 1) kid.ext = {'o': '${d['o'] ?? ''}', 'from': '${d['f'] ?? ''}'};
    kid.inv = {'from': '${d['f'] ?? ''}', 'at': DateTime.now().millisecondsSinceEpoch};
    kid.who = role;
    save();
  }

  /// 가족 연결 코드로 초대 받기(fam.dart 가 서버에서 읽은 초대 [d]). 초대 링크와 같지만 아이에 코드를 붙여
  /// 이 뒤로는 양쪽 휴대폰의 결과가 서버를 거쳐 자동으로 합쳐진다.
  void joinFam(String code, Map d, String role) {
    joinInvite(d, role);
    kid.fam = code;
    kid.inv = {...?kid.inv, 'fam': code};
    save();
  }

  /// 가족 연결로 받은 다른 휴대폰의 양육자 결과를 넣는다. 이 휴대폰에서 직접 답한 같은 이름의 기록은 덮지 않는다.
  /// 바뀐 것이 있으면 true.
  bool putFamRec(Kid k, String who, Rec o) {
    final mine = k.recs[who];
    if (mine != null && mine.hasAny && !mine.recv) return false;
    if (mine != null && mine.recv && mine.t >= o.t) return false;
    k.recs[who] = o;
    return true;
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
