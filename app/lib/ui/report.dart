// 정밀 리포트: 아이·양육자 고르기 + 결과 보고서 머리 + 4탭(기질 / 성격(자라는 힘) / 양육자 비교 / 달라진 점) + 아래 영역
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key});
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  String rtab = 'temp';

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur;
    if (!fullDone(cur.ans)) {
      return AppPage([
        switcher(),
        PaperCard([
          Image.asset('assets/img/mascot_child.webp', width: 96, height: 96),
          h2('아직 정밀검사 결과가 없습니다.'),
          muted('검사를 마치면 이 화면에 결과가 나타납니다.'),
          Btn(cur.paid ? '검사 이어서 하기' : '검사 시작하기', () => startFull(context)),
          Btn('샘플로 보기', store.sample, kind: BtnKind.ghost),
        ]),
      ]);
    }
    final r = score(cur.ans);
    Widget tabBtn(String id, String t) => Expanded(
        child: GestureDetector(
            onTap: () => setState(() => rtab = id),
            child: NineBox(rtab == id ? nChipOn : nChip,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(child: Text(t, style: disp(19, color: rtab == id ? kOnAccent : kMuted))))));
    return AppPage([
      switcher(),
      sheetHead(r),
      col([
        Row(children: [tabBtn('temp', '기질'), const SizedBox(width: 8), tabBtn('grow', '성격(자라는 힘)')]),
        Row(children: [tabBtn('cg', '양육자 비교'), const SizedBox(width: 8), tabBtn('chg', '달라진 점')]),
      ], gap: 8),
      ...switch (rtab) { 'grow' => growTab(r), 'cg' => cgTab(), 'chg' => changeTab(r), _ => tempTab(r) },
      Note(rich(
          "**결과를 읽을 때.** 이 보고서는 ${kid.who}가 관찰한 내용을 바탕으로 하므로 평가자의 시선이 반영됩니다. 다른 양육자가 답하면 결과가 달라질 수 있으며, '양육자 비교' 탭에서 나란히 볼 수 있습니다.${r.cons == '낮음' ? ' 이번 응답은 비슷한 문항 사이에 답이 엇갈린 경우가 많아, 시간을 두고 다시 검사해 보기를 권합니다.' : ''} 점수는 또래와 비교한 순위가 아니라 문항 응답으로 본 아이 안의 경향입니다. 기질에는 좋고 나쁨이 없으며, 이 검사는 의학적 진단이나 발달 평가를 대신하지 않습니다.",
          style: small)),
      Cta([
        h2('${store.nm}의 결과를 함께 보세요', color: kBg),
        const Text('친구·가족에게 결과 카드를 보내거나, 다른 휴대폰의 공동 양육자가 따로 검사하게 초대할 수 있습니다.', style: TextStyle(color: kBg, fontSize: 14, height: 1.6)),
        Btn(kid.inv != null ? '${kid.inv!['from'] ?? '가족'}에게 결과 보내기' : '공유하기', () => tab.value = 2),
      ]),
      Btn('다시 검사하기 · ${Price.fmt(Price.more)}', () => startRetest(context), kind: BtnKind.ghost),
      Fold(
          '시제품 확인용 도구',
          Btn('이 아이 기록 전부 지우기', () {
            store.resetKid();
            tab.value = 0;
          }, kind: BtnKind.ghost)),
    ]);
  }

  /// 아이(둘 이상일 때)와 양육자 고르기
  Widget switcher() {
    final kid = store.kid, ks = store.kids, all = kid.cgs, has = all.map((e) => e.key).toSet();
    final add = kCgl.where((n) => !has.contains(n)).take(3);
    return PaperCard(gap: 10, [
      if (ks.length > 1) ...[
        h3('아이'),
        chips([for (var i = 0; i < ks.length; i++) ChipBtn(ks[i].label(i), on: ks[i].id == kid.id, onTap: () => store.setKid(ks[i].id))]),
      ],
      Row(children: [
        Expanded(child: h3('양육자별 결과')),
        TextButton(onPressed: () => tab.value = 2, child: const Text('다른 휴대폰으로 초대')),
      ]),
      chips([
        for (final e in all)
          ChipBtn('${e.key} · ${fullDone(e.value.ans) ? score(e.value.ans).code : '${answered(e.value.ans)}/${C.items.length}'}', on: e.key == kid.who, onTap: () => store.setWho(e.key)),
        for (final n in add) ChipBtn('+ $n', onTap: () => addCaregiver(context, n)),
      ]),
    ]);
  }

  Widget sheetHead(Result r) {
    final kid = store.kid, cur = store.cur;
    Widget meta(String k, String v) => SizedBox(
        width: 140,
        child: col([Text(k, style: smallMuted), Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))], gap: 0));
    return NineBox(nCard,
        padding: const EdgeInsets.all(14),
        child: col([
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/img/banner_result.webp', fit: BoxFit.cover)),
          NineBox(nDark,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: col([
                const Text('내 아이의 MBTI · 정밀검사', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kAccent)),
                h2('정밀검사 결과 보고서', color: kBg),
                Text('기질 결과와 성격(자라는 힘) 결과', style: TextStyle(fontSize: 13, color: kBg.withValues(alpha: .8))),
              ], gap: 4)),
          Wrap(runSpacing: 10, spacing: 10, children: [
            meta('이름', store.nm),
            meta('연령', kid.age.isEmpty ? '미입력' : kid.age),
            meta('평가자', kid.who),
            meta('검사일', '${cur.date}${cur.prev != null ? ' · 이전 ${cur.prev!.code}' : ''}'),
            meta('문항', '66문항 · 5점 척도'),
            meta('응답 일관성', '${r.cons ?? '판단 불가'} · 잘 모르겠다 ${r.unk}문항'),
          ]),
        ]));
  }

  List<(String, Color)> letters(Result r) => [for (final x in r.ax) (x.letter, x.a.color)];

  // ---------- 기질 탭 ----------
  List<Widget> tempTab(Result r) => [
        PaperCard([
          Row(children: [Expanded(child: eyebrow('기질 유형')), mascot(r.code, size: 96)]),
          codeText(letters(r)),
          h1(C.nick[r.code]!),
          p('${store.nm}${eun(store.nm)} ${oneLine(r)}'),
        ]),
        PaperCard([
          h2('한눈에 보는 기질 프로필'),
          for (final x in r.ax) axisBar(x.a, x.sc),
          muted('가운데 옅은 띠는 균형 구간(40~60)입니다. 점이 끝에 가까울수록 성향이 뚜렷합니다.'),
        ]),
        for (final x in r.ax) axisCard(x),
        PaperCard([
          h2('강점과 살펴볼 점'),
          h3('타고난 강점'),
          for (final x in r.ax) Text('· ${C.poles[x.letter]!.st}', style: small),
          h3('살펴볼 점'),
          for (final x in r.ax) Text('· ${C.poles[x.letter]!.wa}', style: small),
        ]),
        PaperCard([
          h2('${store.nm}에게 잘 통하는 말'),
          for (final x in r.ax) col([muted('${x.pole} 기질에게'), say(C.poles[x.letter]!.say)], gap: 4),
        ]),
      ];

  Widget say(String t, {bool avoid = false}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: avoid ? kColors['c3']! : kAccent, width: 3))),
        child: Text('“$t”',
            style: avoid ? const TextStyle(fontSize: 13, color: kMuted, decoration: TextDecoration.lineThrough) : disp(18, w: FontWeight.w400)),
      );

  Widget axisCard(AxScore x) {
    final pl = C.poles[x.letter]!, bal = x.d < 8;
    return PaperCard([
      Row(children: [
        Expanded(child: col([muted(x.a.q), h2('${x.a.hi} · ${x.a.lo}')], gap: 0)),
        Pill('${x.pole} ${x.clar}', x.a.c),
      ]),
      axisBar(x.a, x.sc),
      rich('**요약.** ${bal ? '두 성향의 가운데에 가깝습니다. 상황에 따라 ${x.a.hi}, ${x.a.lo} 두 모습을 오가며, 굳이 나누면 ${x.pole} 쪽입니다. ' : ''}${pl.sum}'),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final t in pl.tags) Tag('#$t')]),
      Fold(
          '상세 설명과 세부 기질 보기',
          col([
            p(pl.det),
            for (var i = 0; i < x.a.subs.length; i++) subRow(x.a, x.a.subs[i], x.subs[i]),
            muted('이렇게 말해 보세요'),
            say(pl.say),
            say(pl.no, avoid: true),
          ])),
    ]);
  }

  Widget subRow(Ax a, Sub s, int? sc) => sc == null
      ? col([Row(children: [Expanded(child: Text(s.n, style: const TextStyle(fontWeight: FontWeight.w700))), muted('정보 부족')]), muted("이 항목은 '잘 모르겠다'로 답한 문항이 많아 판단하지 않았습니다.")], gap: 2)
      : col([
          Row(children: [Expanded(child: Text(s.n, style: const TextStyle(fontWeight: FontWeight.w700))), muted(sc < 40 ? s.lo : sc > 60 ? s.hi : '중간')]),
          Track(sc, a.c, thin: true),
          Row(children: [Expanded(child: muted(s.lo)), muted(s.hi)]),
        ], gap: 4);

  // ---------- 성격 탭 ----------
  List<Widget> growTab(Result r) {
    const lvName = ['지금 자라는 중', '고르게 자라는 중', '탄탄함'];
    return [
      PaperCard([
        eyebrow('성격 결과'),
        h2('자라는 힘'),
        muted('기질은 타고나지만 끈기, 스스로 힘, 함께 힘은 경험으로 자랍니다. 나이가 어릴수록 낮게 나오는 것이 자연스럽습니다.'),
        for (final x in r.gr)
          x.sc == null
              ? col([Text(x.g.n, style: const TextStyle(fontWeight: FontWeight.w700)), muted("'잘 모르겠다'로 답한 문항이 많아 판단하지 않았습니다.")], gap: 4)
              : col([
                  Row(children: [
                    SizedBox(width: 72, child: Text(x.g.n, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(child: Track(x.sc, 'g', thin: true, fill: true)),
                    SizedBox(width: 36, child: Text('${x.sc}', textAlign: TextAlign.right, style: disp(18))),
                  ]),
                  rich('**${lvName[x.lv!]}.** ${x.g.lv[x.lv!][0]}', style: small),
                  Fold('상세 설명', Text(x.g.lv[x.lv!][1], style: small)),
                ], gap: 6),
      ]),
      cmpCard(r),
    ];
  }

  Widget cmpCard(Result r) {
    final kid = store.kid, c = compareGrow(r, store.cur.prev, kid.who, store.cur.ans);
    const cmpv = [('비슷함', 'c2'), ('자랐음', 'c4'), ('낮아졌음', 'c1')];
    return PaperCard([
      eyebrow('이전 검사와 비교'),
      h2('지난번과 달라진 점'),
      if (c.p != null) muted('이전 검사 ${c.p!.date.isEmpty ? '날짜 없음' : c.p!.date} · 평가자 ${c.p!.who}${c.p!.sample ? ' · 샘플 예시 기록' : ''}'),
      if (c.none)
        rich("**비교 기록 없음.** 비교할 이전 점수가 남아 있지 않습니다. 리포트 아래 '다시 검사하기'를 하면 그 전 점수가 남아 이곳에 나란히 보입니다.", style: small)
      else if (c.otherWho)
        rich('**평가자가 달라 직접 비교하기 어렵습니다.** 이전 검사는 ${c.p!.who}, 이번 검사는 ${kid.who}가 답했습니다.', style: small)
      else ...[
        for (final o in c.rows)
          o.skip != null
              ? col([Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700)), muted("${o.skip}에서 '잘 모르겠다'가 절반 이상이라 비교하지 않았습니다.")], gap: 2)
              : Row(children: [
                  SizedBox(width: 72, child: Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(child: Text('이전 ${o.ps} → 지금 ${o.x.sc}', style: small)),
                  Pill(cmpv[o.v!].$1, cmpv[o.v!].$2),
                ]),
        muted("작은 점수 차이는 답하는 날의 기분이나 상황으로도 생기므로 '비슷함'으로 봅니다. 순위나 진단이 아니라 같은 평가자가 본 변화의 방향입니다."),
      ],
    ]);
  }

  // ---------- 양육자 비교 탭 ----------
  List<Widget> cgTab() {
    final kid = store.kid, nm = store.nm, all = kid.cgs, fin = all.where((e) => fullDone(e.value.ans)).toList();
    final head = [
      eyebrow('양육자 비교'),
      h2('양육자마다 다르게 본 점'),
      muted('같은 아이도 함께 지내는 시간과 장면이 달라 다르게 보일 수 있습니다. 어느 쪽이 맞다는 뜻이 아니라, $nm${ga2(nm)} 사람과 상황에 따라 다른 모습을 보인다는 단서입니다.'),
    ];
    if (fin.length < 2) {
      final has = all.map((e) => e.key).toSet();
      return [
        PaperCard([
          ...head,
          rich("**비교할 양육자가 아직 없습니다.** 정밀검사를 마친 양육자가 두 명 이상이면 이곳에 결과가 나란히 정리됩니다. 지금 마친 사람: ${fin.isEmpty ? '없음' : fin.map((e) => e.key).join(', ')}.", style: small),
          muted('다른 휴대폰을 쓰는 양육자는 초대 링크로 검사하고 결과를 보내 주면 이곳에 합쳐집니다.'),
          chips([
            for (final n in kCgl.where((n) => !has.contains(n)).take(3)) ChipBtn('+ $n', onTap: () => addCaregiver(context, n)),
            ChipBtn('초대 보내기', onTap: () => tab.value = 2),
          ]),
        ])
      ];
    }
    final rs = [for (final e in fin) (who: e.key, rec: e.value, r: score(e.value.ans))];
    final codes = rs.map((x) => x.r.code).toSet();
    final axv = [
      for (var i = 0; i < C.axes.length; i++)
        () {
          final sc = rs.map((x) => x.r.ax[i].sc), letters = rs.map((x) => x.r.ax[i].letter).toSet(), range = sc.reduce(max) - sc.reduce(min);
          final split = letters.length > 1;
          return (a: C.axes[i], i: i, split: split, v: split ? ('시선이 갈림', 'c1') : range >= Cmp.same ? ('정도가 다름', 'c3') : ('비슷하게 봄', 'c2'));
        }()
    ];
    final splitAx = axv.where((x) => x.split).toList();
    final summary = codes.length == 1
        ? '${rs.map((x) => x.who).join(', ')} 모두 **${codes.first} ${C.nick[codes.first]}**로 같은 유형이 나왔습니다.'
        : '${rs.map((x) => '${x.who}는 **${x.r.code}**').join(', ')}로 유형이 다르게 나왔습니다.';
    final summary2 = splitAx.isNotEmpty ? ' **${splitAx.map((x) => '${x.a.hi}·${x.a.lo}').join(', ')}** 축에서 방향이 갈렸고, 나머지 ${4 - splitAx.length}축은 같은 방향입니다.' : ' 네 축 모두 같은 방향으로 보았습니다.';
    final split = [
      for (final it in C.items)
        () {
          final a = rs.map((o) => o.rec.ans[it.id]).whereType<int>().where((x) => x > 0).toList();
          return (it: it, spread: a.length > 1 ? a.reduce(max) - a.reduce(min) : 0);
        }()
    ].where((x) => x.spread >= Cmp.gap).toList()
      ..sort((x, y) => y.spread - x.spread);
    Widget qrow(Item it) => col([
          Text(it.t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Wrap(spacing: 12, children: [for (final o in rs) rich('**${o.who}** ${optName(o.rec.ans[it.id])}', style: small)]),
        ], gap: 2);
    return [
      PaperCard([
        ...head,
        rich(summary + summary2),
        Wrap(spacing: 14, runSpacing: 8, children: [
          for (final o in rs)
            Row(mainAxisSize: MainAxisSize.min, children: [
              mascot(o.r.code, size: 52),
              const SizedBox(width: 6),
              col([Text(o.who, style: const TextStyle(fontWeight: FontWeight.w700)), muted('${o.r.code} · ${o.rec.date}')], gap: 0, x: CrossAxisAlignment.start),
            ]),
        ]),
      ]),
      PaperCard([
        h2('기질 4축, 사람마다'),
        for (final x in axv)
          col([
            Row(children: [Expanded(child: h3('${x.a.hi} · ${x.a.lo}')), Pill(x.v.$1, x.v.$2)]),
            for (final o in rs)
              Row(children: [
                SizedBox(width: 64, child: Text(o.who, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(child: Track(o.r.ax[x.i].sc, x.a.c, thin: true)),
                SizedBox(width: 24, child: Text(o.r.ax[x.i].letter, textAlign: TextAlign.right, style: disp(17))),
              ]),
            Row(children: [const SizedBox(width: 64), Expanded(child: muted('← ${x.a.lo}')), muted('${x.a.hi} →'), const SizedBox(width: 24)]),
            if (x.split) Text('${rs.map((o) => '${o.who}는 ${o.r.ax[x.i].pole}').join(', ')} 쪽으로 보았습니다. ${x.a.q}의 모습이 함께 있는 사람이나 장소에 따라 달라질 수 있습니다.', style: small),
          ], gap: 6),
        muted("점 위치는 0~100 점수입니다. 가운데 옅은 띠(40~60)는 균형 구간입니다. 같은 방향이어도 ${Cmp.same}점 넘게 벌어지면 '정도가 다름'으로 표시합니다."),
      ]),
      PaperCard([
        h2('자라는 힘, 사람마다'),
        for (var gi = 0; gi < C.grows.length; gi++)
          () {
            final sc = rs.map((o) => o.r.gr[gi].sc).toList(), ok = sc.whereType<int>().toList();
            final range = ok.length > 1 ? ok.reduce(max) - ok.reduce(min) : null;
            return Row(children: [
              SizedBox(width: 72, child: Text(C.grows[gi].n, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Text([for (var k = 0; k < rs.length; k++) '${rs[k].who} ${sc[k] ?? '판단 안 함'}'].join(' · '), style: small)),
              if (range != null) Pill(range < Cmp.same ? '비슷하게 봄' : '정도가 다름', range < Cmp.same ? 'c2' : 'c3'),
            ]);
          }(),
      ]),
      PaperCard([
        h2('답이 크게 갈린 문항'),
        if (split.isEmpty)
          muted('${Cmp.gap}칸 이상 벌어진 문항이 없습니다. 양육자들이 $nm${ga2(nm)} 꽤 비슷하게 보고 있습니다.')
        else ...[
          muted('같은 문항에 ${Cmp.gap}칸 이상 다른 답을 고른 문항 ${split.length}개입니다. 이 장면을 언제, 어디서 봤는지 서로 이야기해 보면 아이를 더 넓게 이해할 수 있습니다.'),
          for (final x in split.take(6)) qrow(x.it),
          if (split.length > 6) Fold('나머지 ${split.length - 6}문항 더 보기', col([for (final x in split.skip(6)) qrow(x.it)])),
        ],
      ]),
      Note(rich("**함께 맞춰 보기.** 시선이 갈린 축은 $nm${ga2(nm)} ${splitAx.isNotEmpty ? '그 사람 앞에서' : '상황에 따라'} 다른 모습을 보이는 부분일 수 있습니다. 양육자끼리 '잘 통하는 말'을 하나 정해 같은 말로 대해 주면 아이가 덜 헷갈립니다.", style: small)),
    ];
  }

  // ---------- 달라진 점 탭 ----------
  List<Widget> changeTab(Result r) {
    final kid = store.kid, cur = store.cur, pv = cur.prev;
    final head = [
      eyebrow('이전 검사와 비교 · ${kid.who}'),
      h2('다시 검사로 달라진 점'),
      if (pv != null) muted('이전 검사 ${pv.date.isEmpty ? '날짜 없음' : pv.date} → 이번 검사 ${cur.date} · 평가자 ${pv.who.isEmpty ? kid.who : pv.who}${pv.sample ? ' · 샘플 예시 기록' : ''}'),
    ];
    if (pv == null) {
      return [
        PaperCard([...head, rich("**비교 기록 없음.** ${kid.who}의 이전 검사 기록이 없습니다. 리포트 아래 '다시 검사하기'를 하면 지금 결과가 이전 기록으로 남고, 다시 답한 결과와 나란히 정리됩니다.", style: small)])
      ];
    }
    if (pv.who.isNotEmpty && pv.who != kid.who) {
      return [
        PaperCard([...head, rich("**평가자가 달라 직접 비교하기 어렵습니다.** 이전 검사는 ${pv.who}, 이번 검사는 ${kid.who}가 답했습니다. 양육자 사이의 차이는 '양육자 비교' 탭에서 볼 수 있습니다.", style: small)])
      ];
    }
    final axr = pv.ax == null
        ? []
        : [
            for (final x in r.ax)
              () {
                final ps = pv.ax![x.a.id] ?? 50, d = x.sc - ps, flip = (ps >= 50) != (x.sc >= 50);
                return (
                  x: x, ps: ps, d: d, flip: flip,
                  v: flip ? ('${ps >= 50 ? x.a.hi : x.a.lo} → ${x.pole}', 'c1') : d.abs() < Cmp.same ? ('비슷함', 'c2') : ('${d > 0 ? x.a.hi : x.a.lo} 쪽으로 이동', 'c4')
                );
              }()
          ];
    final moved = axr.where((o) => o.flip || o.d.abs() >= Cmp.same).toList();
    final subs = pv.sub == null
        ? []
        : [
            for (final x in r.ax)
              for (var i = 0; i < x.a.subs.length; i++) (s: x.a.subs[i], ps: pv.sub![x.a.id]?[i], cs: x.subs[i])
          ].where((o) => o.ps != null && o.cs != null && (o.cs! - o.ps!).abs() >= Cmp.sub).toList();
    final pa = pv.ans, ca = cur.ans;
    final ch = pa == null ? <Item>[] : C.items.where((it) => pa[it.id] != null && ca[it.id] != null && pa[it.id] != ca[it.id]).toList();
    final big = ch.where((it) => pa![it.id]! > 0 && ca[it.id]! > 0 && (pa[it.id]! - ca[it.id]!).abs() >= Cmp.gap).toList()
      ..sort((a, b) => (pa![b.id]! - ca[b.id]!).abs() - (pa[a.id]! - ca[a.id]!).abs());
    final unkCh = ch.where((it) => pa![it.id] == 0 || ca[it.id] == 0).length;
    final sum = (pv.code == r.code ? '유형은 **${r.code}** 그대로입니다.' : '유형이 **${pv.code}**에서 **${r.code}**로 바뀌었습니다.') +
        (axr.isNotEmpty ? (moved.isNotEmpty ? ' 4축 중 **${moved.map((o) => '${o.x.a.hi}·${o.x.a.lo}').join(', ')}** 축이 움직였고, 나머지는 비슷합니다.' : ' 4축 모두 비슷합니다.') : '') +
        (pa != null ? ' ${C.items.length}문항 중 **${ch.length}문항**의 답이 바뀌었습니다.' : '');
    Widget qrow(Item it) => col([
          Text(it.t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Wrap(spacing: 12, children: [rich('**이전** ${optName(pa![it.id])}', style: small), rich('**지금** ${optName(ca[it.id])}', style: small)]),
        ], gap: 2);
    final g = compareGrow(r, pv, kid.who, ca);
    const cmpv = [('비슷함', 'c2'), ('자랐음', 'c4'), ('낮아졌음', 'c1')];
    Widget typeMini(String label, String code, {bool faded = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (C.nick.containsKey(code)) Opacity(opacity: faded ? .6 : 1, child: mascot(code, size: 52)),
          const SizedBox(width: 6),
          col([muted(label), rich('**$code** ${C.nick[code] ?? ''}', style: small)], gap: 0, x: CrossAxisAlignment.start),
        ]);
    return [
      PaperCard([
        ...head,
        rich(sum),
        if (pv.code != r.code) Wrap(spacing: 14, runSpacing: 8, children: [typeMini('이전', pv.code, faded: true), typeMini('지금', r.code)]),
      ]),
      if (axr.isNotEmpty)
        PaperCard([
          h2('기질 4축 변화'),
          for (final o in axr)
            col([
              Row(children: [Expanded(child: Text('${o.x.a.hi} · ${o.x.a.lo}', style: const TextStyle(fontWeight: FontWeight.w700))), Pill(o.v.$1, o.v.$2)]),
              Row(children: [
                SizedBox(width: 44, child: Text(o.x.a.lo, style: small)),
                Expanded(child: Track(o.x.sc, o.x.a.c, thin: true, was: o.ps)),
                SizedBox(width: 44, child: Text(o.x.a.hi, textAlign: TextAlign.right, style: small)),
              ]),
              muted('이전 ${o.ps} → 지금 ${o.x.sc}'),
            ], gap: 6),
          muted("빈 동그라미: 이전, 색 점: 지금. ${Cmp.same}점보다 작은 차이는 '비슷함'"),
        ]),
      if (subs.isNotEmpty)
        PaperCard([
          h2('달라진 세부 기질'),
          for (final o in subs)
            col([
              Row(children: [Expanded(child: Text(o.s.n, style: const TextStyle(fontWeight: FontWeight.w700))), Text('이전 ${o.ps} → 지금 ${o.cs}', style: small)]),
              muted('${o.cs! > o.ps! ? o.s.hi : o.s.lo} 쪽으로 ${(o.cs! - o.ps!).abs()}점 움직였습니다.'),
            ], gap: 2),
        ]),
      if (g.rows.isNotEmpty)
        PaperCard([
          h2('자라는 힘 변화'),
          for (final o in g.rows)
            o.skip != null
                ? col([Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700)), muted("${o.skip}에서 '잘 모르겠다'가 절반 이상이라 비교하지 않았습니다.")], gap: 2)
                : Row(children: [
                    SizedBox(width: 72, child: Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(child: Text('이전 ${o.ps} → 지금 ${o.x.sc}', style: small)),
                    Pill(cmpv[o.v!].$1, cmpv[o.v!].$2),
                  ]),
        ]),
      if (pa != null)
        PaperCard([
          h2('답이 크게 바뀐 문항'),
          if (big.isEmpty)
            muted('${Cmp.gap}칸 이상 바뀐 문항은 없습니다.')
          else ...[
            muted('${Cmp.gap}칸 이상 다른 답을 고른 문항 ${big.length}개입니다. 이 장면에서 요즘 무엇이 달라졌는지 떠올려 보세요.'),
            for (final it in big.take(6)) qrow(it),
            if (big.length > 6) Fold('나머지 ${big.length - 6}문항 더 보기', col([for (final it in big.skip(6)) qrow(it)])),
          ],
          if (unkCh > 0) muted("'잘 모르겠다'로 바뀌었거나 '잘 모르겠다'에서 답이 생긴 문항이 $unkCh개 있습니다."),
        ]),
      const Note(Text("두 검사 사이의 차이는 아이가 자란 모습일 수도, 답한 날의 기분이나 최근 일의 영향일 수도 있습니다. 작은 차이는 '비슷함'으로 보고, 크게 바뀐 문항 위주로 살펴보세요.")),
    ];
  }
}

/// 받침이 있으면 '은', 없으면 '는'
String eun(String n) => _jong(n) ? '은' : '는';

/// 받침이 있으면 '가'(이름 뒤 '이가'가 아니라 '가'), 웹과 같이 '가'로 통일
String ga2(String n) => '가';
bool _jong(String n) {
  if (n.isEmpty) return false;
  final c = n.codeUnitAt(n.length - 1);
  return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0;
}
