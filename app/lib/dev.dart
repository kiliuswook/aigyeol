// 성장 발달 체크(2026-11-24 원더 요청): 영유아 건강검진의 발달 선별처럼, 아이의 개월 수에 맞는 문항으로
// 6개 영역(대근육·소근육·인지·언어·사회성·자조)을 보고, 성별 성장 기준(WHO)으로 키·몸무게를 본다.
// 모든 체크는 아이 기록(Kid.devs)에 쌓이고, 같은 개월 구간·성별 아이들의 평균과 비교한다(서버 dstats).
// 설명: docs/systems/dev-check.md. 문항: assets/data/dev.json(자체 문항, 전문가 감수 전 초안).
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'i18n.dart';
import 'stats.dart' show Avg, kStatMin;
import 'store.dart';

/// 문항 하나. m: 대부분의 아이가 해내는 무렵(개월)
class DevItem {
  final String id, d, t, ex;
  final int m;
  DevItem(Map j) : id = j['id'], d = j['d'], t = j['t'], ex = j['ex'], m = j['m'];
}

/// 영역 하나. tips: 나이 묶음(0: 12개월 전, 1: 1~2세, 2: 3~4세, 3: 5세 이상)마다 놀이 팁 두 개
class DevDomain {
  final String id, n, d;
  final List<List<String>> tips;
  DevDomain(Map j) : id = j['id'], n = j['n'], d = j['d'], tips = [for (final x in j['tips']) List<String>.from(x)];
}

class DevContent {
  final List<DevDomain> domains;
  final List<DevItem> items;
  final List<String> opt;
  final Map<String, List<String>> lv;
  final String rg, rgEx;
  DevContent(Map j)
      : domains = [for (final d in j['domains']) DevDomain(d)],
        items = [for (final i in j['items']) DevItem(i)],
        opt = List<String>.from(j['opt']),
        lv = {for (final e in (j['lv'] as Map).entries) '${e.key}': List<String>.from(e.value)},
        rg = j['rg'],
        rgEx = j['rgEx'];
  late final byId = {for (final x in items) x.id: x};
  DevDomain domain(String id) => domains.firstWhere((d) => d.id == id);
}

late DevContent DV;

/// 성별 성장 기준 LMS 표(남 M, 여 F). 0~95개월, 달마다 [L, M, S]. WHO 2006 기준(0~60개월) + WHO 2007 참조(61개월~).
late Map<String, Map<String, List<List<double>>>> _growth;

Future<void> loadDev() async {
  DV = DevContent(jsonDecode(await loadLocalized('assets/data/dev.json')));
  final g = jsonDecode(await rootBundle.loadString('assets/data/growth.json')) as Map;
  _growth = {
    for (final s in ['M', 'F'])
      s: {for (final k in ['h', 'w']) k: [for (final r in g[s][k]) List<double>.from((r as List).map((x) => (x as num).toDouble()))]},
  };
}

// ---------- 개월 구간과 문항 고르기 ----------

/// 개월 구간의 시작(영유아 건강검진 발달 선별처럼 어릴수록 촘촘하게). 마지막 구간은 84~95개월.
const kDevBands = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 27, 30, 33, 36, 42, 48, 54, 60, 66, 72, 84];
const kDevMin = 4, kDevMax = 95;

/// 개월 수 → 구간 시작. 4개월 전이나 8세(96개월)부터는 null.
int? devBand(int mo) {
  if (mo < kDevMin || mo > kDevMax) return null;
  return kDevBands.lastWhere((b) => b <= mo);
}

int bandEnd(int b) {
  final i = kDevBands.indexOf(b);
  return i < kDevBands.length - 1 ? kDevBands[i + 1] - 1 : kDevMax;
}

/// '30~32개월'
String bandLabel(int b) => tr('{0}~{1}개월', [b, bandEnd(b)]);

/// 태어난 해·달('YYYY-MM') 기준 오늘(또는 [now])의 개월 수
int? monthsOf(String birth, [DateTime? now]) {
  final p = birth.split('-'), y = int.tryParse(p[0]), m = p.length > 1 ? int.tryParse(p[1]) : null;
  if (y == null || m == null) return null;
  final n = now ?? DateTime.now();
  final mo = (n.year - y) * 12 + (n.month - m);
  return mo < 0 ? null : mo;
}

/// 발달 체크에 쓰는 개월 수: 태어난 해·달이 있으면 그대로, 없으면 이미 넣은 정보로 어림한다(다시 묻지 않는다).
/// 태어난 해만 있으면 그해 가운데(7월), 나이만 있으면('만 5세') 그 나이의 가운데(N세 6개월). 어림이면 est = true.
(int?, bool) devMonths(String birth, String age, [DateTime? now]) {
  final exact = monthsOf(birth, now);
  if (exact != null) return (exact, false);
  final n = now ?? DateTime.now();
  final y = int.tryParse(birth.split('-')[0]);
  if (y != null && y > 1990) {
    final mo = (n.year - y) * 12 + (n.month - 7);
    return (mo < 0 ? 0 : mo, true);
  }
  final yrs = int.tryParse(RegExp(r'\d+').firstMatch(age)?.group(0) ?? '');
  if (yrs != null) return (yrs * 12 + 6, true);
  return (null, false);
}

/// 구간 [b]에서 묻는 문항: 영역마다 4개. 그 나이에 이미 해낼 무렵인 문항(기대 문항) 최근 3개 + 다음 단계 문항 1개.
/// 다음 단계 문항이 없는 마지막 구간은 기대 문항 4개. 같은 구간이면 늘 같은 문항이라 평균을 낼 수 있다.
List<DevItem> devItems(int b) => [for (final d in DV.domains) ...domainItems(d.id, b)];

List<DevItem> domainItems(String d, int b) {
  final all = DV.items.where((x) => x.d == d).toList()..sort((a, b) => a.m.compareTo(b.m));
  final exp = all.where((x) => x.m <= b).toList(), next = all.where((x) => x.m > b).toList();
  final e = exp.length > 3 ? exp.sublist(exp.length - 3) : exp;
  final c = next.take(4 - e.length).toList();
  if (e.length + c.length < 4) return exp.length >= 4 ? exp.sublist(exp.length - 4) : exp;
  return [...e, ...c];
}

// ---------- 기록 ----------

/// 발달 체크 한 번. ans: 문항 id → 0 아직 못 해요 ~ 3 잘 해요. h 키(cm), w 몸무게(kg)는 넣은 경우만.
/// rg: 해내던 것을 못 하게 된 적(-1 아직 안 답함, 0 없음, 1 있음). st: 통계에 보냈는지.
class DevRec {
  String id, date, who, sex;
  int mo, band, rg, t;
  Map<String, int> ans;
  double? h, w;
  bool st;
  DevRec({String? id, required this.date, required this.who, required this.sex, required this.mo, required this.band, Map<String, int>? ans, this.h, this.w, this.rg = -1, this.st = false, this.t = 0})
      : id = id ?? 'd${rid()}', ans = ans ?? {};
  List<DevItem> get items => devItems(band);
  bool get itemsDone => items.every((x) => ans[x.id] != null);
  bool get done => itemsDone && rg >= 0;
  void touch() => t = DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> toJson() => {
        'id': id, 'date': date, 'who': who, 'sex': sex, 'mo': mo, 'band': band, 'ans': ans,
        if (h != null) 'h': h, if (w != null) 'w': w, 'rg': rg, if (st) 'st': true, if (t > 0) 't': t,
      };
  factory DevRec.fromJson(dynamic j) => DevRec(
        id: '${j['id']}', date: '${j['date'] ?? ''}', who: '${j['who'] ?? ''}', sex: '${j['sex'] ?? ''}',
        mo: (j['mo'] as num?)?.round() ?? 0, band: (j['band'] as num?)?.round() ?? kDevMin,
        ans: j['ans'] is Map ? {for (final e in (j['ans'] as Map).entries) '${e.key}': (e.value as num).round()} : {},
        h: (j['h'] as num?)?.toDouble(), w: (j['w'] as num?)?.toDouble(),
        rg: (j['rg'] as num?)?.round() ?? -1, st: j['st'] == true, t: (j['t'] as num?)?.round() ?? 0,
      );
}

/// 두 기록 목록 합치기(기기 사이 동기화): 같은 id 는 더 최근(t)인 쪽, 없는 것은 더한다. 날짜순.
List<DevRec> mergeDevs(List<DevRec> mine, List<DevRec> other) {
  final m = {for (final r in mine) r.id: r};
  for (final o in other) {
    final l = m[o.id];
    if (l == null || o.t > l.t) m[o.id] = o..st = o.st || (l?.st ?? false);
  }
  return m.values.toList()..sort((a, b) => a.t.compareTo(b.t));
}

// ---------- 판정 ----------

/// 영역 판정: fast 앞서 가요 · ok 또래만큼 · watch 조금 더 지켜봐요 · red 전문가와 살펴봐요
const kLvOrder = ['fast', 'ok', 'watch', 'red'];
const kLvColor = {'fast': 'c4', 'ok': 'g', 'watch': 'c1', 'red': 'c3'};

class DevDomainResult {
  final DevDomain d;
  final int sc; // 0~100
  final String lv;
  final List<DevItem> good, practice; // 잘 해요 / 아직 연습 중(0·1)
  DevDomainResult(this.d, this.sc, this.lv, this.good, this.practice);
}

class DevResult {
  final List<DevDomainResult> ds;
  final bool regress;
  DevResult(this.ds, this.regress);
  int count(String lv) => ds.where((x) => x.lv == lv).length;
  Map<String, int> get vals => {for (final x in ds) x.d.id: x.sc};
}

/// 기대 문항(그 나이에 해낼 무렵인 것) 평균 ea, 다음 단계 문항 평균 ca 로 판정한다(0~3점).
/// ea < 1.5 → red, ea < 2 또는 기대 문항 중 '아직 못 해요'가 있으면 → watch, ea ≥ 2.5 이고 ca ≥ 2 → fast, 나머지 ok.
/// 기준은 자체 초안(전문가 감수 전). 점수(0~100)는 네 문항 합 / 12.
DevResult devScore(DevRec r) {
  final out = <DevDomainResult>[];
  for (final d in DV.domains) {
    final its = domainItems(d.id, r.band);
    final exp = its.where((x) => x.m <= r.band).toList(), nxt = its.where((x) => x.m > r.band).toList();
    int a(DevItem x) => r.ans[x.id] ?? 0;
    final sum = its.fold<int>(0, (s, x) => s + a(x));
    final sc = its.isEmpty ? 0 : (sum * 100 / (its.length * 3)).round();
    final ea = exp.isEmpty ? 3.0 : exp.fold<int>(0, (s, x) => s + a(x)) / exp.length;
    final ca = nxt.isEmpty ? 0.0 : nxt.fold<int>(0, (s, x) => s + a(x)) / nxt.length;
    final lv = ea < 1.5
        ? 'red'
        : (ea < 2 || exp.any((x) => a(x) == 0))
            ? 'watch'
            : (nxt.isNotEmpty && ea >= 2.5 && ca >= 2)
                ? 'fast'
                : 'ok';
    out.add(DevDomainResult(d, sc, lv, [for (final x in its) if (a(x) == 3) x], [for (final x in its) if (a(x) <= 1) x]));
  }
  return DevResult(out, r.rg == 1);
}

/// 놀이 팁 나이 묶음
int tipGroup(int mo) => mo < 12 ? 0 : mo < 36 ? 1 : mo < 60 ? 2 : 3;

// ---------- 성장(키·몸무게) ----------

/// 표준정규분포 누적값
double _phi(double z) {
  // Abramowitz-Stegun 7.1.26
  final t = 1 / (1 + .3275911 * z.abs() / math.sqrt2);
  final y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - .284496736) * t + .254829592) * t * math.exp(-z * z / 2);
  return z >= 0 ? (1 + y) / 2 : (1 - y) / 2;
}

/// 성별·개월 수 기준 z 점수. kind 'h' 키, 'w' 몸무게. 표 밖이면 null.
double? growthZ(String sex, int mo, String kind, double x) {
  final t = _growth[sex]?[kind];
  if (t == null || mo < 0 || mo >= t.length || x <= 0) return null;
  final l = t[mo][0], m = t[mo][1], s = t[mo][2];
  return l == 0 ? math.log(x / m) / s : (math.pow(x / m, l) - 1) / (l * s);
}

/// 백분위(0~100, 같은 성별·개월 수 아이 100명 중 이 값보다 작은 아이 수)
int? growthPct(String sex, int mo, String kind, double x) {
  final z = growthZ(sex, mo, kind, x);
  return z == null ? null : (_phi(z) * 100).round().clamp(0, 100);
}

/// 기준표의 가운데 값(50백분위)
double? growthMedian(String sex, int mo, String kind) {
  final t = _growth[sex]?[kind];
  return (t == null || mo < 0 || mo >= t.length) ? null : t[mo][1];
}

/// 백분위 읽기: 3 미만·97 초과는 상담 권장
String pctNote(int p) => p < 3 ? tr('또래보다 많이 작은 편') : p < 15 ? tr('또래보다 작은 편') : p <= 85 ? tr('또래 가운데쯤') : p <= 97 ? tr('또래보다 큰 편') : tr('또래보다 많이 큰 편');

// ---------- 또래 평균(서버) ----------

const _docs = 'projects/childmbti-wonderwheel/databases/(default)/documents';
const _base = 'https://firestore.googleapis.com/v1/$_docs';
const kDevKeys = ['gm', 'fm', 'cg', 'ln', 'sc', 'sh'];

/// 평균 묶음: 'd<구간 시작>_<M|F>' (예: d30_F)
String devBucket(DevRec r) => 'd${r.band}_${r.sex}';

class DevStats {
  http.Client client = http.Client();
  final _cache = <String, Map<String, Avg>>{};
  final _at = <String, DateTime>{};

  /// 묶음의 영역별 평균(gm~sh), 키 h(cm)·몸무게 w(kg) 평균. 10분 동안은 받은 값을 다시 쓴다. 못 받으면 null.
  Future<Map<String, Avg>?> load(String bucket) async {
    final at = _at[bucket];
    if (at != null && DateTime.now().difference(at).inMinutes < 10) return _cache[bucket];
    try {
      final r = await client.get(Uri.parse('$_base/dstats/$bucket')).timeout(const Duration(seconds: 8));
      if (r.statusCode == 404) {
        _cache[bucket] = {};
      } else if (r.statusCode == 200) {
        _cache[bucket] = parse(jsonDecode(utf8.decode(r.bodyBytes)));
      } else {
        return _cache[bucket];
      }
      _at[bucket] = DateTime.now();
      return _cache[bucket];
    } catch (_) {
      return _cache[bucket];
    }
  }

  static Map<String, Avg> parse(Map doc) {
    final f = (doc['fields'] ?? {}) as Map;
    num v(String k) => num.tryParse('${(f[k] as Map?)?['integerValue'] ?? (f[k] as Map?)?['doubleValue'] ?? ''}') ?? 0;
    final n = v('n').round(), hn = v('hn').round(), wn = v('wn').round();
    return {
      if (n > 0)
        for (final k in kDevKeys) k: (avg: v('s$k') / n, n: n),
      if (hn > 0) 'h': (avg: v('hs') / hn / 10, n: hn), // mm → cm
      if (wn > 0) 'w': (avg: v('ws') / wn / 10, n: wn), // 100g → kg
    };
  }

  /// 체크 한 건을 통계에 더하는 요청 본문: dstats 에 더하기 + dresults 에 한 건(이름·계정 없이)
  static Map<String, dynamic> commitBody(DevRec r, String who, String id) {
    final res = devScore(r), b = devBucket(r);
    final hmm = r.h == null ? null : (r.h! * 10).round(), w100 = r.w == null ? null : (r.w! * 10).round();
    return {
      'writes': [
        {
          'update': {'name': '$_docs/dstats/$b', 'fields': {}},
          'updateMask': {'fieldPaths': []},
          'updateTransforms': [
            {'fieldPath': 'n', 'increment': {'integerValue': '1'}},
            for (final x in res.ds) {'fieldPath': 's${x.d.id}', 'increment': {'integerValue': '${x.sc}'}},
            if (hmm != null) ...[
              {'fieldPath': 'hn', 'increment': {'integerValue': '1'}},
              {'fieldPath': 'hs', 'increment': {'integerValue': '$hmm'}},
            ],
            if (w100 != null) ...[
              {'fieldPath': 'wn', 'increment': {'integerValue': '1'}},
              {'fieldPath': 'ws', 'increment': {'integerValue': '$w100'}},
            ],
          ],
        },
        {
          'update': {
            'name': '$_docs/dresults/$id',
            'fields': {
              'b': {'stringValue': b},
              'mo': {'integerValue': '${r.mo}'},
              'who': {'stringValue': who},
              'sc': {'mapValue': {'fields': {for (final x in res.ds) x.d.id: {'integerValue': '${x.sc}'}}}},
              'a': {'mapValue': {'fields': {for (final e in r.ans.entries) e.key: {'integerValue': '${e.value}'}}}},
              'rg': {'integerValue': '${r.rg}'},
              if (hmm != null) 'h': {'integerValue': '$hmm'},
              if (w100 != null) 'w': {'integerValue': '$w100'},
            },
          },
          'currentDocument': {'exists': false},
          'updateTransforms': [
            {'fieldPath': 'at', 'setToServerValue': 'REQUEST_TIME'},
          ],
        },
      ],
    };
  }

  void clear() {
    _cache.clear();
    _at.clear();
  }

  bool _busy = false;

  /// 아직 보내지 않은 끝난 체크를 보낸다. 인터넷이 없으면 다음에.
  Future<void> submitPending() async {
    if (_busy) return;
    _busy = true;
    try {
      for (final k in List.of(store.kids)) {
        for (final r in List.of(k.devs)) {
          if (r.st || !r.done || (r.sex != 'M' && r.sex != 'F')) continue;
          final who = kCgl.contains(r.who) ? r.who : '기타 양육자';
          final res = await client
              .post(Uri.parse('$_base:commit'), headers: {'content-type': 'application/json'}, body: jsonEncode(commitBody(r, who, rid())))
              .timeout(const Duration(seconds: 10));
          if (res.statusCode != 200) return;
          r.st = true;
          _at.remove(devBucket(r));
          store.save();
        }
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }
}

final devStats = DevStats();

/// 평균 이름: d30_F → 30~32개월 여자아이
String devBucketLabel(DevRec r) => tr('{0} {1}', [bandLabel(r.band), r.sex == 'M' ? tr('남자아이') : tr('여자아이')]);

/// 평균을 보여 주는 최소 건수(기질 통계와 같게)
const kDevStatMin = kStatMin;
