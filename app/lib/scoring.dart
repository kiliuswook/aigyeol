// 채점과 비교. 웹(index.html)의 score, snapshot, compareGrow, CMP 와 같은 규칙.
import 'i18n.dart';
import 'content.dart';

typedef Ans = Map<String, int>; // 문항 id → 1~5, 0 은 '잘 모르겠다'

/// 판정 기준(확정 전 임시, 감수 필요). 웹 CMP 와 같다.
class Cmp {
  static const same = 12.5, unkHalf = 0.5, sub = 25, gap = 2;
}

double? mean(Iterable<num> a) => a.isEmpty ? null : a.fold<num>(0, (x, y) => x + y) / a.length;
int? pct(double? m) => m == null ? null : ((m - 1) * 25).round();
int? val(Item it, Ans ans) {
  final a = ans[it.id];
  if (a == null || a == 0) return null;
  return it.r ? 6 - a : a;
}

class AxScore {
  final Ax a;
  final List<int?> subs;
  final int sc, d;
  AxScore(this.a, this.subs, this.sc) : d = (sc - 50).abs();
  String get letter => sc >= 50 ? a.h : a.l;
  String get pole => sc >= 50 ? a.hi : a.lo;
  String get clar => d >= 20 ? tr('뚜렷함') : d >= 8 ? tr('약간') : tr('균형에 가까움');
}

class GrScore {
  final Grow g;
  final int? sc;
  GrScore(this.g, this.sc);
  int? get lv => sc == null ? null : sc! >= 65 ? 2 : sc! >= 40 ? 1 : 0;
}

class Result {
  final List<AxScore> ax;
  final List<GrScore> gr;
  final String? cons;
  final int unk;
  Result(this.ax, this.gr, this.cons, this.unk);
  String get code => ax.map((x) => x.letter).join();
}

Result score(Ans ans) {
  final ax = [
    for (final a in C.axes)
      () {
        final subs = [
          for (var si = 0; si < a.subs.length; si++)
            pct(mean(C.items.where((x) => x.ax == a.id && x.sub == si).map((x) => val(x, ans)).whereType<int>()))
        ];
        final m0 = mean(subs.whereType<int>());
        return AxScore(a, subs, m0 == null ? 50 : m0.round());
      }()
  ];
  final gr = [
    for (final g in C.grows) GrScore(g, pct(mean(C.items.where((x) => x.gr == g.id).map((x) => val(x, ans)).whereType<int>())))
  ];
  // 응답 일관성: 같은 묶음 안에서 정방향 문항과 역방향 문항(뒤집은 값)의 평균 차이
  final diffs = <double>[];
  for (final g in C.groups) {
    final f = g.where((x) => !x.r).map((x) => val(x, ans)).whereType<int>();
    final r = g.where((x) => x.r).map((x) => val(x, ans)).whereType<int>();
    if (f.isNotEmpty && r.isNotEmpty) diffs.add((mean(f)! - mean(r)!).abs());
  }
  final dm = mean(diffs);
  final raw = ans.values.where((x) => x > 0).toList();
  final flat = raw.length > 20 && raw.toSet().length == 1;
  final cons = dm == null ? null : flat ? tr('낮음') : dm < 0.9 ? tr('높음') : dm < 1.5 ? tr('보통') : tr('낮음');
  return Result(ax, gr, cons, ans.values.where((x) => x == 0).length);
}

int answered(Ans ans) => C.items.where((x) => ans[x.id] != null).length;
bool fullDone(Ans ans) => answered(ans) == C.items.length;
Map<String, int> grUnk(Ans ans) => {for (final g in C.grows) g.id: C.items.where((x) => x.gr == g.id && ans[x.id] == 0).length};

/// 다시 검사하기 직전에 남기는 이전 기록
class Snap {
  final String code, date, who;
  final Map<String, int>? ax;
  final Map<String, List<int?>>? sub;
  final Map<String, int?>? gr;
  final Map<String, int>? unk;
  final Ans? ans;
  final bool sample;
  Snap({required this.code, required this.date, required this.who, this.ax, this.sub, this.gr, this.unk, this.ans, this.sample = false});

  factory Snap.of(Ans ans, String date, String who, {bool sample = false}) {
    final r = score(ans);
    return Snap(
      code: r.code, date: date, who: who, sample: sample,
      ax: {for (final x in r.ax) x.a.id: x.sc},
      sub: {for (final x in r.ax) x.a.id: x.subs},
      gr: {for (final x in r.gr) x.g.id: x.sc},
      unk: grUnk(ans),
      ans: Map.of(ans),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code, 'date': date, 'who': who, if (sample) 'sample': 1,
        if (ax != null) 'ax': ax, if (sub != null) 'sub': sub, if (gr != null) 'gr': gr,
        if (unk != null) 'unk': unk, if (ans != null) 'ans': ans,
      };

  static Snap? fromJson(dynamic j) {
    if (j is! Map) return null;
    Map<String, T>? m<T>(dynamic x, T Function(dynamic) f) => x is Map ? {for (final e in x.entries) '${e.key}': f(e.value)} : null;
    return Snap(
      code: '${j['code'] ?? ''}', date: '${j['date'] ?? ''}', who: '${j['who'] ?? ''}', sample: j['sample'] == 1 || j['sample'] == true,
      ax: m<int>(j['ax'], (v) => (v as num).round()),
      sub: m<List<int?>>(j['sub'], (v) => [for (final x in v as List) x == null ? null : (x as num).round()]),
      gr: m<int?>(j['gr'], (v) => v == null ? null : (v as num).round()),
      unk: m<int>(j['unk'], (v) => (v as num).round()),
      ans: m<int>(j['ans'], (v) => (v as num).round()),
    );
  }
}

/// 성격 탭의 '이전 검사와 비교' (자라는 힘). v: 0 비슷함, 1 자랐음, 2 낮아졌음
class GrowCmpRow {
  final GrScore x;
  final String? skip;
  final int? ps, v;
  GrowCmpRow(this.x, {this.skip, this.ps, this.v});
}

class GrowCmp {
  final bool none, otherWho;
  final Snap? p;
  final List<GrowCmpRow> rows;
  GrowCmp({this.none = false, this.otherWho = false, this.p, this.rows = const []});
}

GrowCmp compareGrow(Result r, Snap? p, String who, Ans ans) {
  if (p == null || p.gr == null || p.unk == null) return GrowCmp(none: true);
  if (p.who != who) return GrowCmp(p: p, otherWho: true);
  final cu = grUnk(ans);
  return GrowCmp(p: p, rows: [
    for (final x in r.gr)
      () {
        final id = x.g.id, half = x.g.count * Cmp.unkHalf, ps = p.gr![id];
        final pb = (p.unk![id] ?? 0) >= half || ps == null, cb = cu[id]! >= half || x.sc == null;
        if (pb || cb) return GrowCmpRow(x, skip: pb && cb ? tr('이전과 이번 검사 모두') : pb ? tr('이전 검사') : tr('이번 검사'));
        final d = x.sc! - ps;
        return GrowCmpRow(x, ps: ps, v: d.abs() < Cmp.same ? 0 : d > 0 ? 1 : 2);
      }()
  ]);
}

String optName(int? a) => a == null ? '-' : a == 0 ? tr('잘 모르겠다') : C.opt[a - 1];
String oneLine(Result r) => tr('{0}입니다.', [r.ax.map((x) => C.poles[x.letter]!.ph).join(listSep)]);
