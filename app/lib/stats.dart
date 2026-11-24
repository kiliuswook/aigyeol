// 또래 평균: 이 앱으로 마친 검사 결과를 나이(만 나이)·성별 묶음마다 모아 지표별 평균을 낸다.
// 서버: Firestore stats/{y<만 나이>_<M|F>} 문서에 전체 건수 n 과 지표마다 점수 합(s<지표>).
//       지표 19개가 모두 나온 검사만 평균에 더한다('잘 모르겠다'가 많아 판단하지 않은 지표가 있으면 평균에서는 뺀다).
//       results/{id} 에는 검사 한 건의 점수(이름·계정 없이 나이·성별·점수만)를 남긴다. 규칙은 저장소 firestore.rules.
// 로그인 없이도 되도록 Firestore REST 로 읽고 쓴다(앱·웹 같은 길).
import 'i18n.dart';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;
import 'package:http/http.dart' as http;
import 'content.dart';
import 'scoring.dart';
import 'store.dart';

/// 평균을 보여 주는 최소 검사 건수
const kStatMin = 5;

/// 기기에 설정된 나라(ISO 두 글자 대문자, 예: KR). 모르면 null.
String? deviceCountry() {
  final c = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
  return c != null && RegExp(r'^[A-Z]{2}$').hasMatch(c) ? c : null;
}

/// 지금 쓰는 나라(테스트에서 바꿔 끼운다)
String? Function() countryOf = deviceCountry;

/// 나라 묶음 이름: 'c<나라>_<묶음>' (예: cKR_y5_F, cUS_d30_M)
String countryBucket(String cc, String b) => 'c${cc}_$b';

/// 나라 코드 → 국기 그림 글자(🇰🇷)
String flagOf(String cc) => String.fromCharCodes(cc.codeUnits.map((u) => 0x1F1E6 + u - 65));

/// 평균과 그 범위(cc: 나라 평균이면 나라 코드, 전체 국가 평균이면 null)
typedef Scoped = ({Map<String, Avg>? m, String? cc});

/// 지표별 평균의 건수(모든 지표가 같다)
int avgN(Map<String, Avg>? m) => m == null || m.isEmpty ? 0 : m.values.first.n;

/// 보여 주는 평균은 늘 전체 국가 평균이다(2026-11-24 원더 요청 "평균은 무조건 전체 국가로").
/// 나라 묶음은 서버에 계속 쌓기만 하고 화면에는 쓰지 않는다.
Future<Scoped> pickScoped(Future<Map<String, Avg>?> Function(String b) load, String b) async => (m: await load(b), cc: null);
const _docs = 'projects/childmbti-wonderwheel/databases/(default)/documents';
const _base = 'https://firestore.googleapis.com/v1/$_docs';

/// 검사 한 건의 지표 점수: 축 A~D, 세부 기질 A0~D2, 자라는 힘 G1~G3 (판단하지 않은 지표는 빠진다)
Map<String, int> statVals(Result r) => {
      for (final x in r.ax) ...{
        x.a.id: x.sc,
        for (var i = 0; i < x.subs.length; i++)
          if (x.subs[i] != null) '${x.a.id}$i': x.subs[i]!,
      },
      for (final g in r.gr)
        if (g.sc != null) g.g.id: g.sc!,
    };

/// 모든 지표 이름(규칙의 허용 목록과 같아야 한다)
List<String> get statKeys => [
      for (final a in C.axes) ...[a.id, for (var i = 0; i < a.subs.length; i++) '${a.id}$i'],
      for (final g in C.grows) g.id,
    ];

/// 검사한 날('YYYY.MM.DD') 기준 개월 수. 태어난 해·달이 없으면 예전에 고른 '만 N세'로 어림한다.
int? ageMonths(Kid k, String date) {
  final b = k.birth.split('-'), d = date.split('.');
  final by = int.tryParse(b[0]), bm = b.length > 1 ? int.tryParse(b[1]) : null;
  final now = DateTime.now(), dy = d.length == 3 ? int.tryParse(d[0]) ?? now.year : now.year, dm = d.length == 3 ? int.tryParse(d[1]) ?? now.month : now.month;
  if (by != null && bm != null) {
    final mo = (dy - by) * 12 + (dm - bm);
    return mo < 0 ? null : mo;
  }
  final y = int.tryParse(RegExp(r'\d+').firstMatch(k.age)?.group(0) ?? '');
  return y == null ? null : y * 12 + 6;
}

/// 평균 묶음 이름. 나이(0~12세)와 성별이 모두 있어야 한다.
String? bucketOf(Kid k, String date) {
  final mo = ageMonths(k, date);
  if (mo == null || mo ~/ 12 > 12 || (k.sex != 'M' && k.sex != 'F')) return null;
  return 'y${mo ~/ 12}_${k.sex}';
}

/// 'y5_M' → '만 5세 남자아이'
String bucketLabel(String b) {
  final m = RegExp(r'^y(\d+)_([MF])$').firstMatch(b);
  return m == null ? '' : tr('만 {0}세 {1}', [m[1], m[2] == 'M' ? tr('남자아이') : tr('여자아이')]);
}

typedef Avg = ({double avg, int n});

class Stats {
  /// 테스트에서 바꿔 끼운다
  http.Client client = http.Client();
  final _cache = <String, Map<String, Avg>>{};
  final _at = <String, DateTime>{};

  /// 전체 국가 평균
  Future<Scoped> loadScoped(String bucket) async {
    if (store.demo != null) return (m: _demo(), cc: null);
    return pickScoped(load, bucket);
  }

  /// 묶음의 지표별 평균(건수 포함). 10분 동안은 받은 값을 다시 쓴다. 못 받으면 null.
  Future<Map<String, Avg>?> load(String bucket) async {
    if (store.demo != null) return _demo();
    final at = _at[bucket];
    if (at != null && DateTime.now().difference(at).inMinutes < 10) return _cache[bucket];
    try {
      final r = await client.get(Uri.parse('$_base/stats/$bucket')).timeout(const Duration(seconds: 8));
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

  /// Firestore 문서 → 지표별 평균
  static Map<String, Avg> parse(Map doc) {
    final f = (doc['fields'] ?? {}) as Map;
    num v(String k) => num.tryParse('${(f[k] as Map?)?['integerValue'] ?? (f[k] as Map?)?['doubleValue'] ?? ''}') ?? 0;
    final n = v('n').round();
    return {
      if (n > 0)
        for (final k in statKeys) k: (avg: v('s$k') / n, n: n),
    };
  }

  /// 샘플 리포트용 예시 평균(서버에 묻지 않는다)
  Map<String, Avg> _demo() {
    var i = 0;
    return {for (final k in statKeys) k: (avg: 44.0 + (i++ * 7) % 19, n: 128)};
  }

  /// 검사 한 건을 통계에 더하는 요청 본문. [cc]가 있으면 그 나라 묶음에도 더한다(전체 국가 묶음과 함께).
  static Map<String, dynamic> commitBody(String bucket, Map<String, int> vals, int months, String who, String id, {String? cc}) => {
        'writes': [
          if (vals.length == statKeys.length)
            for (final b in [bucket, if (cc != null) countryBucket(cc, bucket)])
              {
                'update': {'name': '$_docs/stats/$b', 'fields': {}},
                'updateMask': {'fieldPaths': []},
                'updateTransforms': [
                  {'fieldPath': 'n', 'increment': {'integerValue': '1'}},
                  for (final e in vals.entries) {'fieldPath': 's${e.key}', 'increment': {'integerValue': '${e.value}'}},
                ],
              },
          {
            'update': {
              'name': '$_docs/results/$id',
              'fields': {
                'b': {'stringValue': bucket},
                'mo': {'integerValue': '$months'},
                'who': {'stringValue': who},
                if (cc != null) 'cc': {'stringValue': cc},
                'sc': {'mapValue': {'fields': {for (final e in vals.entries) e.key: {'integerValue': '${e.value}'}}}},
              },
            },
            'currentDocument': {'exists': false},
            'updateTransforms': [
              {'fieldPath': 'at', 'setToServerValue': 'REQUEST_TIME'},
            ],
          },
        ],
      };

  /// 받아 둔 평균을 버린다(테스트용)
  void clear() {
    _cache.clear();
    _at.clear();
  }

  bool _busy = false;

  /// 아직 통계에 보내지 않은 끝난 검사를 보낸다(예전에 한 검사도 포함). 나이·성별이 없는 아이는 넣을 때까지 미룬다.
  /// 샘플과 다른 휴대폰에서 받은 결과는 보내지 않는다(받은 결과는 보낸 휴대폰이 센다).
  Future<void> submitPending() async {
    if (_busy) return;
    _busy = true;
    try {
      for (final k in List.of(store.kids)) {
        for (final e in List.of(k.recs.entries)) {
          final rec = e.value;
          if (rec.st || rec.sample || rec.recv || !rec.paid || !fullDone(rec.ans)) continue;
          final b = bucketOf(k, rec.date), mo = ageMonths(k, rec.date);
          if (b == null || mo == null) continue;
          final who = kCgl.contains(e.key) ? e.key : '기타 양육자';
          final r = await client
              .post(Uri.parse('$_base:commit'), headers: {'content-type': 'application/json'}, body: jsonEncode(commitBody(b, statVals(score(rec.ans)), mo, who, rid(), cc: countryOf())))
              .timeout(const Duration(seconds: 10));
          if (r.statusCode != 200) return;
          rec.st = true;
          _at.remove(b);
          final cc = countryOf();
          if (cc != null) _at.remove(countryBucket(cc, b));
          store.save();
        }
      }
    } catch (_) {
      // 인터넷이 없으면 다음에 다시 보낸다
    } finally {
      _busy = false;
    }
  }
}

final stats = Stats();
