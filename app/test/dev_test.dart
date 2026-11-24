// 성장 발달 체크 계산: 개월 구간, 문항 고르기, 판정, 성장 백분위(WHO), 통계 요청, 기록 합치기
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:childmbti/dev.dart';
import 'package:childmbti/stats.dart' show countryOf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDev);

  test('개월 수: 태어난 해·달 그대로, 없으면 이미 있는 정보로 어림', () {
    final n = DateTime(2026, 11, 24);
    expect(devMonths('2024-05', '', n), (30, false));
    expect(devMonths('2022-', '만 4세', n), (52, true)); // 해만 있으면 그해 7월로
    expect(devMonths('', '만 5세', n), (66, true));
    expect(devMonths('', '', n), (null, false));
  });

  test('개월 구간: 4~95개월, 경계', () {
    expect(devBand(3), null);
    expect(devBand(4), 4);
    expect(devBand(5), 4);
    expect(devBand(26), 24);
    expect(devBand(35), 33);
    expect(devBand(83), 72);
    expect(devBand(95), 84);
    expect(devBand(96), null);
    expect(bandEnd(84), 95);
    expect(monthsOf('2023-05', DateTime(2025, 11, 3)), 30);
  });

  test('모든 구간에서 영역마다 4문항, 같은 문항이 두 번 나오지 않는다', () {
    for (final b in kDevBands) {
      final its = devItems(b);
      expect(its.length, 24, reason: '$b');
      expect(its.map((x) => x.id).toSet().length, 24);
      for (final d in DV.domains) {
        final ds = its.where((x) => x.d == d.id).toList();
        expect(ds.length, 4);
        // 다음 단계 문항은 많아야 하나 + 기대 문항이 하나도 없는 영역은 없다(4개월 자조 제외: 기대 1개)
        expect(ds.where((x) => x.m <= b).isNotEmpty, true, reason: '$b ${d.id}');
      }
    }
  });

  test('판정: 모두 잘 해요 → 앞서 가요, 모두 대체로 → 또래만큼, 기대 문항 아직 못 해요 → 지켜봐요/전문가', () {
    DevRec make(int Function(DevItem) f) {
      final r = DevRec(date: '2026.11.24', who: '엄마', sex: 'F', mo: 30, band: 30, rg: 0);
      for (final x in r.items) {
        r.ans[x.id] = f(x);
      }
      return r;
    }

    expect(devScore(make((_) => 3)).ds.every((x) => x.lv == 'fast' && x.sc == 100), true);
    expect(devScore(make((_) => 2)).ds.every((x) => x.lv == 'ok'), true);
    expect(devScore(make((x) => x.m <= 30 ? 3 : 0)).ds.every((x) => x.lv == 'ok'), true);
    final one0 = make((x) => x.d == 'ln' && x.m == 24 ? 0 : 3);
    expect(devScore(one0).ds.firstWhere((x) => x.d.id == 'ln').lv, 'watch');
    expect(devScore(make((_) => 1)).ds.every((x) => x.lv == 'red'), true);
    expect(devScore(make((_) => 3)..rg = 1).regress, true);
  });

  test('성장 백분위: WHO 가운데 값은 50, 성별에 따라 다르다', () {
    expect(growthPct('M', 24, 'h', growthMedian('M', 24, 'h')!), 50);
    expect(growthPct('F', 60, 'w', growthMedian('F', 60, 'w')!), 50);
    expect(growthPct('F', 72, 'h', growthMedian('F', 72, 'h')!), 50);
    // 24개월 남아 키 가운데 값 87.8cm(WHO 표)
    expect(growthMedian('M', 24, 'h')!.toStringAsFixed(1), '87.8');
    // 같은 키라도 여자아이 백분위가 더 높다
    expect(growthPct('F', 36, 'h', 96)! > growthPct('M', 36, 'h', 96)!, true);
    // +2SD 쯤이면 약 98백분위
    expect(growthPct('M', 36, 'h', 103.5)!, greaterThanOrEqualTo(96));
    expect(growthPct('M', 96, 'h', 120), null);
  });

  test('통계 요청: dstats 더하기 + dresults 한 건, 키 mm·몸무게 100g 단위', () {
    final r = DevRec(date: '2026.11.24', who: '엄마', sex: 'M', mo: 31, band: 30, h: 92.4, w: 13.6, rg: 0);
    for (final x in r.items) {
      r.ans[x.id] = 2;
    }
    final b = DevStats.commitBody(r, '엄마', 'x1');
    final s = jsonEncode(b);
    expect(s.contains('dstats/d30_M'), true);
    expect(s.contains('dresults/x1'), true);
    final tf = (b['writes'] as List).first['updateTransforms'] as List;
    expect(tf.length, 1 + 6 + 4);
    expect(s.contains('"integerValue":"924"'), true);
    expect(s.contains('"integerValue":"136"'), true);
    final p = DevStats.parse({'fields': {'n': {'integerValue': '4'}, 'sgm': {'integerValue': '280'}, 'hn': {'integerValue': '2'}, 'hs': {'integerValue': '1850'}}});
    expect(p['gm']!.avg, 70);
    expect(p['h']!.avg, 92.5);
    expect(p['w'], null);
  });

  test('기록 합치기: 같은 id 는 최근 것, 없는 것은 더한다', () {
    final a = DevRec(id: 'a', date: '', who: '엄마', sex: 'F', mo: 30, band: 30, t: 1);
    final a2 = DevRec(id: 'a', date: '', who: '엄마', sex: 'F', mo: 30, band: 30, t: 5, h: 90);
    final c = DevRec(id: 'c', date: '', who: '아빠', sex: 'F', mo: 30, band: 30, t: 3);
    final m = mergeDevs([a], [a2, c]);
    expect(m.length, 2);
    expect(m.firstWhere((x) => x.id == 'a').h, 90);
    expect(DevRec.fromJson(jsonDecode(jsonEncode(a2.toJson()))).h, 90);
  });

  test('또래 평균: 성별을 모르면 남녀 묶음을 건수로 가중해 합친다', () async {
    final st = DevStats()
      ..client = MockClient((q) async {
        final m = q.url.path.endsWith('_M');
        return http.Response(jsonEncode({'fields': {'n': {'integerValue': m ? '2' : '6'}, 'sgm': {'integerValue': m ? '100' : '540'}}}), 200);
      });
    countryOf = () => null;
    final a = (await st.loadFor(30, '')).m!;
    expect(a['gm']!.n, 8);
    expect(a['gm']!.avg, 80); // (100 + 540) / 8
    final f = (await st.loadFor(30, 'F')).m!;
    expect(f['gm']!.avg, 90);
  });

  test('또래 평균: 같은 나라 체크가 30건 이상이면 나라 평균, 아니면 전체 국가', () async {
    var cn = 40;
    final st = DevStats()
      ..client = MockClient((q) async {
        final c = q.url.path.contains('/cKR_d30_');
        return http.Response(jsonEncode({'fields': {'n': {'integerValue': c ? '$cn' : '100'}, 'sgm': {'integerValue': c ? '${cn * 70}' : '5000'}}}), 200);
      });
    countryOf = () => 'KR';
    final k = await st.loadFor(30, 'F');
    expect(k.cc, 'KR');
    expect(k.m!['gm']!.avg, 70);
    cn = 10;
    st.clear();
    final g = await st.loadFor(30, 'F');
    expect(g.cc, isNull);
    expect(g.m!['gm']!.avg, 50);
    final r = DevRec(id: 'a', date: '', who: '엄마', sex: 'F', mo: 30, band: 30, t: 1);
    final w = DevStats.commitBody(r, '엄마', 'x', cc: 'KR')['writes'] as List;
    expect(w.length, 3);
    expect((w[1]['update'] as Map)['name'], endsWith('/dstats/cKR_d30_F'));
    expect(((w[2]['update'] as Map)['fields'] as Map)['cc'], {'stringValue': 'KR'});
    countryOf = () => null;
  });
}
