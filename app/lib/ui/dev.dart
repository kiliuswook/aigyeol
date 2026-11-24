// 성장 발달 체크 화면: 시작(개월 수·성별 확인, 보상형 광고) → 키·몸무게 → 문항 한 개씩 → 결과(요약 · 영역 상세 · 키·몸무게 · 또래 평균 · 지난 기록)
// 화면 틀은 다른 화면과 같다: 한 화면(Frame) + 요약에서 한 단계 들어가기(Drill) + 설명은 가운데 팝업.
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../ads.dart';
import '../dev.dart';
import 'peer.dart';
import '../main.dart' show tab;
import '../store.dart';
import 'kit.dart';
import 'report.dart' show Drill;
import 'setup.dart' show editKid;

String lvName(String lv) => DV.lv[lv]![0];
/// 좁은 칸용 짧은 판정 이름
String lvShort(String lv) => DV.lv[lv]!.length > 2 ? DV.lv[lv]![2] : DV.lv[lv]![0];
String sexTx(String s) => s == 'M' ? tr('남자아이') : s == 'F' ? tr('여자아이') : '';

/// 발달 체크 열기: 아래 메뉴 '성장 발달' 탭으로
void openDev(BuildContext ctx) {
  Navigator.of(ctx).popUntil((r) => r.isFirst);
  tab.value = 4;
}

/// 홈 줄에 쓰는 지금 상태 한 줄
String devStatus(Kid k) {
  final last = k.devLast, open = k.devOpen;
  if (open != null && open.band == devBand(devMonths(k.birth, k.age).$1 ?? -1)) return tr('체크 중 · {0}/{1}', [open.ans.length, open.items.length]);
  if (last != null) {
    final r = devScore(last), good = r.count('fast') + r.count('ok');
    return tr('{0} · 6개 영역 중 {1}개 또래만큼', [last.date, good]);
  }
  return tr('개월 수에 맞춘 6개 영역 + 키·몸무게');
}

class DevScreen extends StatefulWidget {
  /// 아래 메뉴 '성장 발달' 탭 안에 놓일 때(닫기 대신 탭 제목과 아이 고르기)
  final bool inTab;
  const DevScreen({super.key, this.inTab = false});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  /// 결과가 있어도 시작 화면을 볼 때(다시 체크하기)
  bool fresh = false;
  bool busy = false;
  String kidId = '';

  /// 위 줄: 탭이면 제목 + 지금 아이 이름, 따로 연 화면이면 닫기 줄
  Widget bar() {
    if (!widget.inTab) return TopBar(tr('성장 발달 체크'), close: true);
    // 아이는 홈에서 고른다
    return tabTitle(tr('성장 발달'), right: kidTag(store.nm, many: store.kids.length > 1, onTap: () => tab.value = 0));
  }

  Future<void> start() async {
    if (busy) return;
    setState(() => busy = true);
    final r = await ads.showRewarded();
    if (!mounted) return;
    setState(() => busy = false);
    if (r == RewardResult.skipped) {
      toast(context, tr('광고를 끝까지 보면 발달 체크가 열려요.'));
      return;
    }
    final rec = store.startDev();
    if (rec == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevTestScreen(rec)));
    if (mounted) setState(() => fresh = false);
  }

  Future<void> resume(DevRec r) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevTestScreen(r)));
    if (mounted) setState(() => fresh = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        // 아이를 바꾸면 그 아이의 결과부터
        if (store.kid.id != kidId) {
          kidId = store.kid.id;
          fresh = false;
        }
        final last = store.kid.devLast;
        return last != null && !fresh ? result(last) : intro();
      },
    );
    return widget.inTab ? body : Scaffold(body: SafeArea(child: body));
  }

  // ---------- 시작 ----------
  Widget intro() {
    final kid = store.kid, nm = store.nm;
    final (mo, est) = devMonths(kid.birth, kid.age);
    final b = mo == null ? null : devBand(mo);
    // 나이를 전혀 모를 때만 아이 정보를 묻는다. 태어난 달·성별이 빠져 있으면 어림하거나 건너뛰고, 아래에 작게 알려 준다.
    final needInfo = mo == null, noSex = kid.sex != 'M' && kid.sex != 'F';
    final open = kid.devOpen, canResume = open != null && b != null && open.band == b;
    Widget line(String t, String d) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Image.asset('assets/ui/i_check.webp', width: 18, height: 18)),
          const SizedBox(width: 8),
          Expanded(child: rich('**$t** $d', style: small)),
        ]);
    final String msg;
    if (needInfo) {
      msg = tr('개월 수에 맞춰 문항을 고릅니다. {0}의 태어난 해와 달을 넣어 주세요.', [nm]);
    } else if (b == null) {
      msg = mo < kDevMin ? tr('생후 4개월부터 체크할 수 있어요.') : tr('발달 체크는 생후 4개월부터 만 7세(95개월)까지의 아이를 위한 것이에요.');
    } else {
      msg = '';
    }
    return Frame(
      top: bar(),
      body: Fit(
          align: Alignment.center,
          col([
            Center(child: Image.asset('assets/img/mascot_child.webp', width: 84, height: 84)),
            col([
              eyebrow([nm, if (kid.ageText.isNotEmpty) ageTx(kid.ageText), if (mo != null && !est) tr('{0}개월', [mo]), sexTx(kid.sex)].where((x) => x.isNotEmpty).join(' · ')),
              h1(tr('{0}, 잘 자라고 있을까요?', [nm])),
            ], gap: 4),
            if (msg.isNotEmpty)
              Note(Text(msg))
            else
              PaperCard([
                line(tr('무료'), tr('광고 1번을 끝까지 보면 체크가 열려요 · 결제 없음')),
                line(tr('개월 수에 맞춘 문항'), tr('{0} 아이에게 맞춘 24문항', [bandLabel(b!)])),
                line(tr('6개 영역'), DV.domains.map((d) => d.n).join(' · ')),
                line(tr('성별 성장 기준'), tr('키·몸무게를 같은 성별·개월 수 아이들과 비교(WHO 기준)')),
                line(tr('또래 평균 비교'), tr('이 앱에서 체크한 같은 개월·성별 아이들의 평균')),
              ], gap: 9),
            if (msg.isEmpty && (est || noSex))
              GestureDetector(
                onTap: () => editKid(context),
                child: Text(
                    [if (est) tr('태어난 달이 없어 {0}개월쯤으로 어림했어요.', [mo]), if (noSex) tr('성별이 없으면 키·몸무게 백분위와 또래 평균은 빠져요.'), tr('넣으면 더 정확해져요 ›')].join(' '),
                    style: const TextStyle(fontSize: 12.5, color: kAccentInk)),
              ),
            muted(tr('영유아 건강검진의 발달 선별처럼 부모가 관찰한 모습으로 봅니다. 진단이 아니며, 걱정되는 점은 소아청소년과에서 확인해 주세요.')),
          ], gap: 12)),
      foot: [
        if (needInfo)
          Btn(tr('아이 정보 넣기'), () => editKid(context), kind: BtnKind.dark)
        else if (b != null && canResume)
          Btn(tr('이어서 하기 ({0}/{1})', [open.ans.length, open.items.length]), () => resume(open), kind: BtnKind.dark)
        else if (b != null)
          Btn(busy ? tr('광고를 불러오는 중…') : tr('광고 보고 무료로 발달 체크 시작'), start, kind: BtnKind.dark),
        if (kid.devLast != null) Center(child: linkBtn(tr('지난 결과 보기'), () => setState(() => fresh = false))),
      ],
    );
  }

  // ---------- 결과 ----------
  Widget result(DevRec r) {
    final res = devScore(r), nm = store.nm;
    final good = res.count('fast') + res.count('ok');
    final String head;
    if (res.count('red') > 0) {
      head = tr('{0}개 영역은 전문가와 함께 살펴보기를 권해요', [res.count('red')]);
    } else if (res.count('watch') > 0) {
      head = tr('{0}개 영역은 또래만큼, {1}개는 조금 더 지켜봐요', [good, res.count('watch')]);
    } else if (res.count('fast') > 0) {
      head = tr('6개 영역 모두 또래만큼, {0}개는 앞서 가요', [res.count('fast')]);
    } else {
      head = tr('6개 영역 모두 또래만큼 자라요');
    }
    return Frame(
      top: bar(),
      body: Drill(
          key: ValueKey('dev-${r.id}-${r.t}'),
          tabIndex: widget.inTab ? 4 : -1,
          (open) => {
                'root': col([
                  eyebrow(tr('{0} · {1} 문항 · {2} 답함', [r.date, bandLabel(r.band), cg(r.who)])),
                  Text(head, style: disp(23)),
                  for (var i = 0; i < res.ds.length; i++)
                    GestureDetector(
                      key: Key('dev-d$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => open('d$i'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: isKo ? 58 : 92, child: Text(res.ds[i].d.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(isKo ? 18 : 15))),
                          Expanded(child: Track(res.ds[i].sc, 'g', thin: true, fill: true)),
                          const SizedBox(width: 8),
                          SizedBox(width: 108, child: Pill(lvShort(res.ds[i].lv), kLvColor[res.ds[i].lv]!)),
                          Image.asset('assets/ui/i_tri.webp', width: 12, height: 12),
                        ]),
                      ),
                    ),
                  if (res.regress) Note(Text(tr('해내던 것을 못 하게 된 적이 있다고 답했어요. 이런 변화는 소아청소년과에서 꼭 상담해 보세요.'))),
                  if (growthLine(r).isNotEmpty) Text(growthLine(r), maxLines: 2, style: smallMuted),
                  Row(children: [
                    Expanded(child: Btn(tr('키 · 몸무게'), () => open('growth'), kind: BtnKind.ghost, dense: true)),
                    const SizedBox(width: 8),
                    Expanded(child: Btn(tr('또래 평균'), () => open('peer'), kind: BtnKind.ghost, dense: true, icon: peerIcon(20))),
                  ]),
                  Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                    linkBtn(tr('지난 기록'), () => open('hist')),
                    linkBtn(tr('읽는 법'), info),
                    linkBtn(tr('다시 체크하기'), () => setState(() => fresh = true)),
                  ]),
                ], gap: 8),
                for (var i = 0; i < res.ds.length; i++) 'd$i': domainPage(r, res.ds[i]),
                'growth': growthPage(r),
                'peer': peerPage(r, res),
                'hist': histPage(),
              }),
      foot: [if (res.count('red') > 0 || res.regress) muted(tr('{0}의 발달이 걱정된다면 영유아 건강검진(발달 선별검사)이나 소아청소년과 상담을 받아 보세요.', [nm]))],
    );
  }

  /// 요약에 보이는 성장 한 줄: '키 92.5cm 48백분위 · 몸무게 13.1kg 52백분위'
  String growthLine(DevRec r) => [
        for (final (k, v, u) in [('h', r.h, 'cm'), ('w', r.w, 'kg')])
          if (v != null) '${k == 'h' ? tr('키') : tr('몸무게')} $v$u${growthPct(r.sex, r.mo, k, v) == null ? '' : ' (${tr('{0}백분위', [growthPct(r.sex, r.mo, k, v)])})'}',
      ].join(' · ');

  void info() => popup(context, title: tr('발달 체크 읽는 법'), (c, set) => [
        Text(tr('개월 수 구간마다 영역별로 네 문항을 묻습니다. 그 나이에 대부분의 아이가 해내는 모습 세 가지와, 조금 뒤에 해내는 다음 단계 한 가지입니다.'), style: small),
        Text(tr("답은 '잘 해요' 3점부터 '아직 못 해요' 0점까지입니다. 점수는 네 문항 합을 100점으로 바꾼 값이고, 판정은 그 나이에 해낼 무렵인 문항을 중심으로 합니다."), style: small),
        for (final lv in kLvOrder) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 108, child: Pill(lvShort(lv), kLvColor[lv]!)), const SizedBox(width: 6), Expanded(child: Text(DV.lv[lv]![1], style: smallMuted))]),
        muted(tr('키·몸무게 백분위는 WHO 성장 기준(만 5세까지)과 WHO 성장 참조치(만 5세 이후)로 계산합니다. 또래 평균은 이 앱에서 같은 개월 구간·성별로 체크한 결과를 모은 값입니다.')),
        muted(tr('문항과 판정 기준은 공개된 발달 이정표를 참고해 만든 자체 문항이며, 진단 도구가 아닙니다. 아이마다 자라는 속도가 다르므로 한 번의 결과보다 흐름을 보세요.')),
      ]);

  Widget domainPage(DevRec r, DevDomainResult x) {
    final tips = x.d.tips[tipGroup(r.mo)];
    Widget list(String t, List<DevItem> its) => col([
          Text(t, style: disp(19)),
          for (final it in its) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('·  ', style: small), Expanded(child: Text(it.t, style: small))]),
        ], gap: 2);
    return col([
      eyebrow(tr('발달 영역')),
      Row(children: [Expanded(child: h2(x.d.n)), Flexible(child: Pill(lvName(x.lv), kLvColor[x.lv]!))]),
      muted(x.d.d),
      Row(children: [Expanded(child: Track(x.sc, 'g', fill: true)), SizedBox(width: 44, child: Text('${x.sc}', textAlign: TextAlign.right, style: disp(20)))]),
      Text(DV.lv[x.lv]![1], style: small),
      if (x.good.isNotEmpty) list(tr('잘 해요'), x.good),
      if (x.practice.isNotEmpty) list(tr('아직 연습 중'), x.practice),
      NineBox(nPink, padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: col([Text(tr('이렇게 놀아 주세요'), style: disp(18)), for (final t in tips) Text(t, style: small)], gap: 4)),
    ], gap: 10);
  }

  Future<void> growthInput(DevRec r) async {
    final h = TextEditingController(text: r.h?.toString() ?? ''), w = TextEditingController(text: r.w?.toString() ?? '');
    await popup(context, title: tr('키 · 몸무게'), (c, set) => [
          muted(tr('최근에 잰 값을 넣어 주세요. 비워 두면 넣지 않습니다.')),
          PaperField(h, hint: tr('키 (cm)'), keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 5),
          PaperField(w, hint: tr('몸무게 (kg)'), keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 5),
          Btn(tr('저장'), () {
            store.devGrowth(r, parseH(h.text), parseW(w.text));
            Navigator.of(c).pop();
          }, kind: BtnKind.dark),
        ]);
  }

  Widget growthPage(DevRec r) {
    Widget one(String kind, double v) {
      final p = growthPct(r.sex, r.mo, kind, v), med = growthMedian(r.sex, r.mo, kind);
      final unit = kind == 'h' ? 'cm' : 'kg';
      return PaperCard([
        Row(children: [
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(kind == 'h' ? tr('키') : tr('몸무게'), style: disp(20)),
                    const SizedBox(width: 10),
                    Text('$v$unit', style: disp(26)),
                  ]))),
          if (p != null) Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(tr('{0}백분위', [p]), style: disp(20, color: kAccentInk)))),
        ]),
        if (p != null) ...[
          Track(p, 'c4', thin: true),
          Text(tr('같은 성별·개월 수 아이 100명 중 작은 쪽부터 {0}번째쯤 · {1}', [p == 0 ? 1 : p, pctNote(p)]), style: small),
        ],
        if (med != null) muted(tr('기준 가운데 값 {0}{1}', [med.toStringAsFixed(1), unit])),
      ], gap: 6);
    }

    return col([
      eyebrow(tr('성별 성장 기준')),
      h2(tr('키 · 몸무게')),
      if (r.h == null && r.w == null) muted(tr('이번 체크에는 키와 몸무게를 넣지 않았어요.')),
      if (r.h != null) one('h', r.h!),
      if (r.w != null) one('w', r.w!),
      Center(child: linkBtn(r.h == null && r.w == null ? tr('키 · 몸무게 넣기') : tr('키 · 몸무게 고치기'), () => growthInput(r))),
      muted(tr('{0} {1}개월 기준. 3백분위 미만이나 97백분위 초과가 이어지면 소아청소년과와 상담해 보세요.', [sexTx(r.sex), r.mo])),
    ], gap: 10);
  }

  Widget peerPage(DevRec r, DevResult res) => FutureBuilder(
      // 성별을 모르면 같은 개월 구간 남녀 전체 평균으로 바로 보여 준다
      future: devStats.loadScope(r.band, r.sex, '*'),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        // 평균은 언제나 모든 나라를 합친 값
        final all = snap.data?.m;
        final label = r.sex == 'M' || r.sex == 'F' ? devBucketLabel(r) : tr('{0} 아이들', [bandLabel(r.band)]), n = all?['gm']?.n ?? 0;
        return col([
          eyebrow(tr('또래 평균')),
          h2(tr('{0} 평균과 비교', [label])),
          if (all == null)
            Text(tr('평균을 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.'), style: small)
          else if (n < kDevStatMin)
            peerCollecting(label)
          else ...[
            Wrap(spacing: 12, runSpacing: 4, children: [
              legend('dot_g', store.nm),
              legend('dot_ring', tr('또래 평균')),
            ]),
            for (final x in res.ds)
              Row(children: [
                SizedBox(width: isKo ? 58 : 92, child: Text(x.d.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(isKo ? 18 : 15))),
                Expanded(child: Track(x.sc, 'g', thin: true, was: all[x.d.id]!.avg.round())),
                SizedBox(width: 64, child: Text(diffTx(x.sc - all[x.d.id]!.avg), textAlign: TextAlign.right, style: smallMuted)),
              ]),
          ],
          if (all != null)
            for (final (k, v, unit) in [('h', r.h, 'cm'), ('w', r.w, 'kg')])
              if ((all[k]?.n ?? 0) >= kDevStatMin)
                Text(tr('{0} 또래 평균 {1}{2}{3}', [k == 'h' ? tr('키') : tr('몸무게'), all[k]!.avg.toStringAsFixed(1), unit, v == null ? '' : tr(' · 우리 아이 {0}{1}', [v, unit])]), style: small),
          muted(tr('이 앱에서 같은 개월 구간·성별로 체크한 결과의 평균입니다. 아이마다 자라는 속도가 달라 평균보다 낮아도 자연스러운 경우가 많습니다.')),
        ], gap: 10);
      });

  Widget legend(String dot, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/ui/$dot.webp', width: 12, height: 12),
        const SizedBox(width: 4),
        Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted)),
      ]);

  String diffTx(double d) => d.abs() < 3 ? tr('비슷') : d > 0 ? '+${d.round()}' : '${d.round()}';

  Widget histPage() {
    final all = store.kid.devs.where((r) => r.done).toList().reversed.toList();
    return col([
      eyebrow(tr('지난 기록')),
      h2(tr('{0}의 발달 체크 {1}번', [store.nm, all.length])),
      Wrap(spacing: 10, runSpacing: 4, children: [for (final lv in kLvOrder) legend('dot_${kLvColor[lv]}', lvName(lv))]),
      for (final r in all)
        PaperCard([
          Row(children: [
            Expanded(child: Text(tr('{0} · {1}개월', [r.date, r.mo]), style: const TextStyle(fontWeight: FontWeight.w700, color: kFg))),
            if (r.h != null) Text('${r.h}cm ', style: smallMuted),
            if (r.w != null) Text('${r.w}kg', style: smallMuted),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final x in devScore(r).ds) Pill('${x.d.n} ${x.sc}', kLvColor[x.lv]!)]),
        ], gap: 6),
      muted(tr('개월 구간마다 문항이 달라서 점수보다 판정(색)의 흐름을 보세요.')),
    ], gap: 10);
  }
}

double? parseH(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  return v == null || v < 40 || v > 160 ? null : (v * 10).round() / 10;
}

double? parseW(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  return v == null || v < 2 || v > 60 ? null : (v * 10).round() / 10;
}

/// 체크하기: 키·몸무게(건너뛸 수 있음) → 문항 24개 → 해내던 것을 못 하게 된 적
class DevTestScreen extends StatefulWidget {
  final DevRec rec;
  const DevTestScreen(this.rec, {super.key});
  @override
  State<DevTestScreen> createState() => _DevTestScreenState();
}

class _DevTestScreenState extends State<DevTestScreen> {
  late final List<DevItem> items = widget.rec.items;
  /// -1 키·몸무게, 0..n-1 문항, n 마지막 질문
  late int i;
  final h = TextEditingController(), w = TextEditingController();
  int? picked;

  @override
  void initState() {
    super.initState();
    final r = widget.rec;
    h.text = r.h?.toString() ?? '';
    w.text = r.w?.toString() ?? '';
    if (r.ans.isEmpty && r.h == null && r.w == null) {
      i = -1;
    } else {
      final k = items.indexWhere((x) => r.ans[x.id] == null);
      i = k < 0 ? items.length : k;
    }
  }

  Future<void> pick(int a) async {
    if (picked != null) return;
    final r = widget.rec;
    if (i < items.length) {
      store.devAnswer(r, items[i].id, a);
    } else {
      store.devRegress(r, a);
    }
    setState(() => picked = a);
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    picked = null;
    if (i < items.length) {
      setState(() => i++);
    } else {
      Navigator.of(context).pop();
      devStats.submitPending();
    }
  }

  Widget opt(int k, String label, bool sel) => GestureDetector(
        key: Key('dev-opt-$k'),
        onTap: () => pick(k),
        child: NineBox(sel || picked == k ? nOptSel : nOpt,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: kFg))),
              if (picked == k) Image.asset('assets/ui/i_check.webp', width: 22, height: 22),
            ])),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.rec, n = items.length, nm = store.nm;
    final top = Row(children: [
      InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox(width: 40, height: 44, child: Center(child: Image.asset('assets/ui/i_close.webp', width: 22, height: 22))),
      ),
      Expanded(child: ProgressBar(((i < 0 ? 0 : i) / (n + 1)).clamp(0, 1).toDouble())),
      SizedBox(width: 64, child: Text(i < 0 ? '' : '${(i + 1).clamp(1, n + 1)} / ${n + 1}', textAlign: TextAlign.right, style: smallMuted)),
    ]);
    final Widget body;
    final List<Widget> foot;
    if (i < 0) {
      body = Fit(
          align: Alignment.center,
          col([
            eyebrow(tr('성별 성장 기준')),
            h1(tr('{0}의 키와 몸무게를 알려 주세요', [nm])),
            muted(tr('최근에 잰 값이면 됩니다. 몰라도 건너뛰고 나중에 넣을 수 있어요.')),
            PaperField(h, hint: tr('키 (cm)'), keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 5),
            PaperField(w, hint: tr('몸무게 (kg)'), keyboard: const TextInputType.numberWithOptions(decimal: true), maxLength: 5),
          ], gap: 12));
      foot = [
        Btn(tr('다음'), () {
          store.devGrowth(r, parseH(h.text), parseW(w.text));
          setState(() => i = 0);
        }, kind: BtnKind.dark),
        Center(child: linkBtn(tr('잘 몰라요, 건너뛰기'), () => setState(() => i = 0))),
      ];
    } else if (i < n) {
      final it = items[i], cur = r.ans[it.id];
      body = AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Fit(
              key: ValueKey(it.id),
              align: Alignment.center,
              col([
                muted(tr('{0} · 요즘 {1}의 모습', [DV.domain(it.d).n, nm])),
                Text(it.t, style: disp(25, w: FontWeight.w700)),
                Note(rich(tr('**예** {0}', [it.ex]), style: small)),
              ], gap: 12)));
      foot = [
        for (var k = 3; k >= 0; k--) opt(k, DV.opt[k], cur == k),
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
          linkBtn(tr('← 이전 문항'), () => setState(() => i--)),
          linkBtn(tr('답하기 애매할 때'), () => popup(context, title: tr('답하기 애매할 때'), (c, set) => [
                Text(tr('본 적이 없다면 오늘 한번 해 보게 하고 답해 주세요. 하기 싫어서 안 하는 것과 아직 못 하는 것은 다릅니다.'), style: small),
                Text(tr("어린이집·유치원에서는 하는데 집에서는 안 한다면 '대체로 해요'를 골라 주세요."), style: small),
                Btn(tr('확인'), () => Navigator.of(c).pop(), kind: BtnKind.ghost),
              ])),
        ]),
      ];
    } else {
      body = Fit(
          align: Alignment.center,
          col([
            muted(tr('마지막 질문')),
            Text(DV.rg, style: disp(25, w: FontWeight.w700)),
            Note(Text(DV.rgEx, style: small)),
          ], gap: 12));
      foot = [
        opt(0, tr('없어요'), r.rg == 0),
        opt(1, tr('있어요'), r.rg == 1),
        Row(children: [linkBtn(tr('← 이전 문항'), () => setState(() => i = n - 1))]),
      ];
    }
    return Scaffold(body: SafeArea(child: Frame(top: top, body: body, foot: foot)));
  }
}
