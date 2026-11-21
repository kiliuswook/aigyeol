// 오늘 탭의 데이터: 부모 칭찬 스티커 미션, 아이와의 약속·일정, 상황 카드. 설명은 docs/systems/today.md
// 문장은 모두 assets/data/daily.json 에 미리 써 둔 것이다(AI 호출 없음).
// 기록은 이 휴대폰에만 둔다(SharedPreferences 'childmbti_daily'). 계정 동기화에는 아직 넣지 않았다.
import 'i18n.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content.dart';
import 'notify.dart';
import 'scoring.dart';
import 'store.dart';

class Mission {
  final String k, t, w; // 종류(말하기·칭찬·행동·참기·관찰), 할 일, 왜 통하는지
  Mission(Map j) : k = j['k'], t = j['t'], w = j['w'];
}

class SitTip {
  final String say, act, no;
  SitTip(Map j) : say = j['say'], act = j['do'], no = j['no'];
}

class Situation {
  final String id, cat, t, p, ax; // 분류, 제목, 공통 원칙, 기준 축(A~D)
  final Map<String, SitTip> by; // 극(E, I …) → 대처
  Situation(Map j)
      : id = j['id'], cat = j['cat'], t = j['t'], p = j['p'], ax = j['ax'],
        by = {for (final e in (j['by'] as Map).entries) e.key as String: SitTip(e.value)};
}

class Notice {
  final String when, t;
  Notice(Map j) : when = j['when'], t = j['t'];
}

/// 형제 궁합 한 축의 한 경우(둘 다 앞 글자 hh / 둘 다 뒤 글자 ll / 서로 다름 mix)
class SibAx {
  final String good, clash, tip, sit;
  final List<String> play;
  SibAx(Map j) : good = j['good'], clash = j['clash'], tip = j['tip'], sit = j['sit'], play = List<String>.from(j['play']);
}

class Sib {
  final Map<String, Map<String, SibAx>> axes; // 축 id → hh/ll/mix
  final Map<String, String> praise; // 극 → 칭찬 한마디
  final List<List<String>> level; // 같은 축 수(0~4) → [이름, 설명]
  Sib(Map j)
      : axes = {for (final e in (j['axes'] as Map).entries) e.key as String: {for (final x in (e.value as Map).entries) x.key as String: SibAx(x.value)}},
        praise = Map<String, String>.from(j['praise']),
        level = [for (final x in j['level']) List<String>.from(x)];
}

class Daily {
  final Map<String, List<Mission>> missions;
  final Sib sib;
  final List<Situation> situations;
  final Map<String, List<Notice>> notice;
  final List<String> plans;
  Daily(Map j)
      : missions = {for (final e in (j['missions'] as Map).entries) e.key as String: [for (final m in e.value) Mission(m)]},
        situations = [for (final s in j['situations']) Situation(s)],
        notice = {for (final e in (j['notice'] as Map).entries) e.key as String: [for (final n in e.value) Notice(n)]},
        plans = List<String>.from(j['plans']),
        sib = Sib(j['sib']);
}

late Daily D;
Future<void> loadDaily() async => D = Daily(jsonDecode(await loadLocalized('assets/data/daily.json')));

/// 아이의 유형: 지금 양육자의 검사가 끝났으면 그것, 아니면 검사를 마친 다른 양육자의 것. 아무도 안 했으면 null.
Result? kidResult(Kid k) {
  if (fullDone(k.cur.ans)) return score(k.cur.ans);
  for (final r in k.recs.values) {
    if (fullDone(r.ans)) return score(r.ans);
  }
  return null;
}

/// 극 글자 → 이름(탐험형 …)
String poleName(String l) {
  for (final a in C.axes) {
    if (a.h == l) return tr('{0}형', [a.hi]);
    if (a.l == l) return tr('{0}형', [a.lo]);
  }
  return '';
}

String dkey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dparse(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime get today0 {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// 미션이 바뀌는 시각: 매일 오전 9시(2026-11-20 원더). 오전 9시 전에는 어제 미션이 이어진다.
const kMissionHour = 9;

/// 지금 보여 줄 미션의 날(오전 9시 기준)
DateTime get missionDay {
  final n = DateTime.now().subtract(const Duration(hours: kMissionHour));
  return DateTime(n.year, n.month, n.day);
}

/// 하루 미션 기록
class Day {
  String id; // 미션 번호 'E3'
  String st; // 아이가 고른 스티커(유형 그림 코드, 예: ENFP). 비어 있으면 아직 안 함
  int r; // 아이 반응 0 잘 통했어요, 1 그냥 그랬어요, 2 안 통했어요, -1 없음
  String memo;
  int sw; // '다른 미션' 누른 횟수
  Day({this.id = '', this.st = '', this.r = -1, this.memo = '', this.sw = 0});
  bool get done => st.isNotEmpty;
  Map<String, dynamic> toJson() => {if (id.isNotEmpty) 'id': id, if (st.isNotEmpty) 'st': st, if (r >= 0) 'r': r, if (memo.isNotEmpty) 'memo': memo, if (sw > 0) 'sw': sw};
  factory Day.fromJson(Map j) => Day(id: '${j['id'] ?? ''}', st: '${j['st'] ?? ''}', r: (j['r'] as num?)?.round() ?? -1, memo: '${j['memo'] ?? ''}', sw: (j['sw'] as num?)?.round() ?? 0);
}

/// 아이와의 약속(promise) 또는 일정
class Plan {
  final String id, kid;
  String t, d, tm; // 내용, 날짜 'YYYY-MM-DD', 시각 'HH:MM'(없으면 '')
  bool pr, done;
  String st; // 약속을 지켰을 때 받은 스티커
  Plan({required this.id, required this.kid, required this.t, required this.d, this.tm = '', this.pr = true, this.done = false, this.st = ''});
  DateTime get date => dparse(d);
  Map<String, dynamic> toJson() => {'id': id, 'kid': kid, 't': t, 'd': d, if (tm.isNotEmpty) 'tm': tm, 'pr': pr, if (done) 'done': true, if (st.isNotEmpty) 'st': st};
  factory Plan.fromJson(Map j) =>
      Plan(id: '${j['id']}', kid: '${j['kid']}', t: '${j['t'] ?? ''}', d: '${j['d']}', tm: '${j['tm'] ?? ''}', pr: j['pr'] != false, done: j['done'] == true, st: '${j['st'] ?? ''}');
}

class DailyStore extends ChangeNotifier {
  static const _k = 'childmbti_daily';
  SharedPreferences? _sp;
  final Map<String, Map<String, Day>> days = {}; // 아이 id → 날짜 → 기록
  final List<Plan> plans = [];
  // 푸시 알림(이 휴대폰 안의 예약 알림). 기본 켜짐, 처음 앱을 켤 때 권한을 묻는다(asked). 더보기 > 푸시 알림에서 끄고 켠다.
  bool alarm = true; // 오늘의 미션 알림(매일 오전 9시)
  bool eve = true; // 저녁 확인 알림(오후 8:30, 그날 해 봤으면 생략)
  bool planAlarm = true; // 약속·일정 알림(하루 전, 1시간 전)
  bool asked = false;
  static const pm = 20 * 60 + 30;

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    final s = _sp!.getString(_k);
    if (s == null) return;
    try {
      final j = jsonDecode(s) as Map;
      for (final e in ((j['days'] ?? {}) as Map).entries) {
        days['${e.key}'] = {for (final d in (e.value as Map).entries) '${d.key}': Day.fromJson(d.value)};
      }
      plans.addAll([for (final p in (j['plans'] ?? []) as List) Plan.fromJson(p)]);
      alarm = j['alarm'] != false;
      eve = j['eve'] != false;
      planAlarm = j['plan'] != false;
      asked = j['asked'] == true;
    } catch (_) {}
  }

  void save() {
    _sp?.setString(_k, jsonEncode({
      'days': {for (final e in days.entries) e.key: {for (final d in e.value.entries) d.key: d.value.toJson()}},
      'plans': [for (final p in plans) p.toJson()],
      'alarm': alarm, 'eve': eve, 'plan': planAlarm, 'asked': asked,
    }));
    notifyListeners();
    unawaited(notify.reschedule());
  }

  Day day(Kid k, DateTime d) => (days[k.id] ??= {}).putIfAbsent(dkey(d), () => Day());
  Day? peek(Kid k, DateTime d) => days[k.id]?[dkey(d)];

  /// 이 아이에게 맞는 미션 목록의 극들. 검사 전이면 공통(X)
  List<String> poles(Kid k) => kidResult(k)?.ax.map((x) => x.letter).toList() ?? ['X'];

  /// 그날의 미션. 날짜·아이마다 정해지고, '다른 미션'을 누르면 다음 것으로 바뀐다. 해 본 날은 그때 미션 그대로.
  (String, Mission) mission(Kid k, DateTime d) {
    final rec = peek(k, d);
    if (rec != null && rec.done && rec.id.isNotEmpty) {
      final m = byId(rec.id);
      if (m != null) return (rec.id, m);
    }
    final ps = poles(k);
    final n = d.difference(DateTime(2026, 1, 1)).inDays + (rec?.sw ?? 0);
    final pole = ps[n % ps.length];
    final list = D.missions[pole]!;
    final i = (n ~/ ps.length + k.key.codeUnits.fold<int>(0, (a, b) => a + b)) % list.length;
    return ('$pole$i', list[i]);
  }

  Mission? byId(String id) {
    final list = D.missions[id.substring(0, 1)];
    final i = int.tryParse(id.substring(1));
    return list == null || i == null || i >= list.length ? null : list[i];
  }

  void swap(Kid k) {
    day(k, missionDay).sw++;
    save();
  }

  void complete(Kid k, {required String sticker, required int react, required String memo}) {
    final d = day(k, missionDay);
    d.id = mission(k, missionDay).$1;
    d.st = sticker;
    d.r = react;
    d.memo = memo;
    save();
  }

  void undo(Kid k) {
    final d = day(k, missionDay);
    d.st = '';
    d.r = -1;
    save();
  }

  /// 스티커 수: 미션을 해 본 날 + 지킨 약속
  int stickers(Kid k, {DateTime? from}) =>
      (days[k.id]?.entries.where((e) => e.value.done && (from == null || !dparse(e.key).isBefore(from))).length ?? 0) +
      plans.where((p) => p.kid == k.id && p.pr && p.done && (from == null || !p.date.isBefore(from))).length;

  /// 연속으로 해 본 날(오늘 아직 안 했으면 어제까지)
  int streak(Kid k) {
    var d = missionDay;
    if (!(peek(k, d)?.done ?? false)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (peek(k, d)?.done ?? false) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// '잘 통했어요'가 많았던 미션 종류(관찰 기록 요약용)
  List<(String, String)> goodLog(Kid k, {int max = 20}) {
    final out = <(String, String)>[];
    final es = (days[k.id]?.entries.toList() ?? [])..sort((a, b) => b.key.compareTo(a.key));
    for (final e in es) {
      if (e.value.done && (e.value.r == 0 || e.value.memo.isNotEmpty)) {
        final m = byId(e.value.id);
        if (m != null) out.add((e.key, e.value.memo.isNotEmpty ? e.value.memo : m.t));
      }
      if (out.length >= max) break;
    }
    return out;
  }

  List<Plan> plansOf(Kid k) => plans.where((p) => p.kid == k.id).toList()..sort((a, b) => '${a.d}${a.tm}'.compareTo('${b.d}${b.tm}'));

  void addPlan(Plan p) {
    plans.add(p);
    save();
  }

  void finishPlan(Plan p, {String sticker = ''}) {
    p.done = true;
    p.st = sticker;
    save();
  }

  void reopenPlan(Plan p) {
    p.done = false;
    p.st = '';
    save();
  }

  void removePlan(Plan p) {
    plans.remove(p);
    save();
  }

  void setAlarm({bool? mission, bool? evening, bool? plan}) {
    if (mission != null) alarm = mission;
    if (evening != null) eve = evening;
    if (plan != null) planAlarm = plan;
    save();
  }

  bool get anyAlarm => alarm || eve || planAlarm;

  /// 앱을 다시 열었을 때·오전 9시가 지날 때: 화면의 미션을 새 날 것으로 바꾸고 알림을 다시 건다
  void refresh() {
    notifyListeners();
    unawaited(notify.reschedule());
  }

  Timer? _clock;

  /// 앱이 켜져 있는 동안 다음 오전 9시에 미션을 바꾼다
  void startClock() {
    _clock?.cancel();
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, kMissionHour);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    _clock = Timer(next.difference(now) + const Duration(seconds: 1), () {
      refresh();
      startClock();
    });
  }

  /// 일정 앞에 무엇을 미리 알려 줄지: 아이의 리듬·섬세·탐험 축 극에서 고른다. 검사 전이면 리듬형 기준.
  List<(String, Notice)> notices(Kid k) {
    final r = kidResult(k);
    final ls = r == null ? ['J'] : [for (final x in r.ax) if (D.notice.containsKey(x.letter)) x.letter];
    final order = [tr('3일 전'), tr('전날 저녁'), tr('당일 아침')];
    final out = [for (final l in ls) for (final n in D.notice[l]!) (l, n)];
    out.sort((a, b) => order.indexOf(a.$2.when).compareTo(order.indexOf(b.$2.when)));
    return out;
  }
}

final daily = DailyStore();

/// 시각(분) → '오전 9:00'
String hm(int m) {
  final h = m ~/ 60, mi = m % 60;
  return '${h < 12 ? tr('오전') : tr('오후')} ${h % 12 == 0 ? 12 : h % 12}:${mi.toString().padLeft(2, '0')}';
}
