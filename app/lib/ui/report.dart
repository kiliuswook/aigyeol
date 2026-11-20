// 정밀 리포트: 아이·양육자 고르기 + 결과 보고서 머리 + 4탭(기질 / 성격(자라는 힘) / 양육자 비교 / 달라진 점) + 아래 영역
import 'dart:math';
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'insight.dart';
import '../stats.dart';
import 'kit.dart';
import 'share.dart' show inviteCg, openShare;
import 'setup.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key});
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  String rtab = 'temp';

  @override
  Widget build(BuildContext context) {
    final cur = store.cur;
    if (!fullDone(cur.ans)) {
      return Frame(
        top: tabTitle('리포트'),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          switcher(),
          Expanded(
              child: Fit(
                  align: Alignment.center,
                  col([
                    Center(child: Image.asset('assets/img/mascot_child.webp', width: 120, height: 120)),
                    Center(child: h2('아직 정밀검사 결과가 없습니다.')),
                    const Center(child: Text('검사를 마치면 이 화면에 결과가 나타납니다.', style: smallMuted)),
                  ]))),
        ]),
        foot: [
          Btn(cur.paid ? '검사 이어서 하기' : '검사 시작하기', () => startFull(context), kind: BtnKind.dark),
          Btn('샘플로 보기', () => showSample(context), kind: BtnKind.ghost),
        ],
      );
    }
    final r = score(cur.ans);
    Widget tabBtn(String id, String t) => Expanded(
        flex: t.length + 2,
        child: GestureDetector(
            onTap: () => setState(() => rtab = id),
            child: NineBox(rtab == id ? nChipOn : nChip,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, style: disp(17, color: rtab == id ? kOnAccent : kMuted)))))));
    return Frame(
      top: col(gap: 8, [
        switcher(),
        Row(children: [
          tabBtn('temp', '기질'), const SizedBox(width: 6), tabBtn('grow', '자라는 힘'),
          const SizedBox(width: 6), tabBtn('cg', '양육자 비교'), const SizedBox(width: 6), tabBtn('chg', '달라진 점'),
        ]),
      ]),
      // 탭·아이·양육자가 바뀌면 요약 화면부터
      body: Drill(
          key: ValueKey('$rtab-${store.kid.id}-${store.kid.who}'),
          (open) => switch (rtab) { 'grow' => growTab(r, open), 'cg' => cgTab(open), 'chg' => changeTab(r, open), _ => tempTab(r, open) }),
    );
  }

  /// 요약 한 장 + 줄마다 '자세히 보기'. pages[0] 이 요약, 나머지는 제목 줄로 들어간다.
  Map<String, Widget> hub(void Function(String) open, List<String> titles, List<Widget> pages) => {
        'root': col([
          pages[0],
          for (var i = 1; i < pages.length; i++) Row(children: [Expanded(child: Text(titles[i], style: disp(19))), MoreBtn(() => open('p$i'))]),
        ], gap: 8),
        for (var i = 1; i < pages.length; i++) 'p$i': pages[i],
      };

  /// 아이(둘 이상일 때는 눌러서 고르기)와 양육자 고르기: 한 줄, 옆으로 밀어 보기
  Widget switcher() {
    final kid = store.kid, ks = store.kids, all = kid.cgs;
    return chipRow([
      if (ks.length > 1 && store.demo == null)
        ChipBtn('${store.nm} ▾',
            onTap: () => popup(context, title: '아이 고르기', (c, set) => [
                  for (var i = 0; i < ks.length; i++)
                    Tile('${ks[i].label(i)}${fullDone(ks[i].cur.ans) ? ' · ${score(ks[i].cur.ans).code}' : ''}', sub: ks[i].ageText.isEmpty ? null : ks[i].ageText, onTap: () {
                      store.setKid(ks[i].id);
                      Navigator.of(c).pop();
                    }),
                ])),
      for (final e in all)
        ChipBtn('${e.key} · ${fullDone(e.value.ans) ? score(e.value.ans).code : '${answered(e.value.ans)}/${C.items.length}'}', on: e.key == kid.who, onTap: () => store.setWho(e.key)),
      if (store.demo == null) ChipBtn('+ 추가', onTap: () => addWho(context, invite: () => inviteCg(context))),
    ]);
  }

  void info(Result r) {
    final kid = store.kid;
    popup(context, title: '검사 정보와 결과 읽는 법', (c, set) => [
          rich('66문항 · 5점 척도 · 응답 일관성 **${r.cons ?? '판단 불가'}** · 잘 모르겠다 ${r.unk}문항', style: small),
          muted(
              "이 보고서는 ${kid.who}가 관찰한 내용을 바탕으로 하므로 평가자의 시선이 반영됩니다. 다른 양육자가 답하면 결과가 달라질 수 있으며, '양육자 비교' 탭에서 나란히 볼 수 있습니다.${r.cons == '낮음' ? ' 이번 응답은 비슷한 문항 사이에 답이 엇갈린 경우가 많아, 시간을 두고 다시 검사해 보기를 권합니다.' : ''} 점수는 또래와 비교한 순위가 아니라 문항 응답으로 본 아이 안의 경향입니다. 기질에는 좋고 나쁨이 없으며, 이 검사는 의학적 진단이나 발달 평가를 대신하지 않습니다."),
          muted('막대 가운데 옅은 띠는 균형 구간(40~60)입니다. 끝에 가까울수록 뚜렷합니다.'),
        ]);
  }

  List<(String, Color)> letters(Result r) => [for (final x in r.ax) (x.letter, x.a.color)];

  // ---------- 기질 탭 ----------
  bool showWatch = false;
  Map<String, Widget> tempTab(Result r, void Function(String) open) {
    final kid = store.kid, cur = store.cur;
    return {
      // 요약: 유형과 네 축. 축마다 자세히 보기
      'root': col([
        Row(children: [
          mascot(r.code, size: 92),
          const SizedBox(width: 12),
          Expanded(
              child: col([
            eyebrow('정밀검사 결과 · ${cur.date}'),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: codeText(letters(r), size: 42)),
            Text(C.nick[r.code]!, style: disp(23)),
          ], gap: 0, x: CrossAxisAlignment.start)),
        ]),
        Text('${store.nm}${eun(store.nm)} ${oneLine(r)}', style: small),
        for (var i = 0; i < r.ax.length; i++)
          col([
            Row(children: [
              Expanded(
                  child: Row(children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${r.ax[i].a.hi} · ${r.ax[i].a.lo}', maxLines: 1, style: disp(19)))),
                avgBtn(r.ax[i].a.id, '${r.ax[i].a.hi} · ${r.ax[i].a.lo}', r.ax[i].sc, r.ax[i].a.c, lo: r.ax[i].a.lo, hi: r.ax[i].a.hi),
              ])),
              MoreBtn(() => open('ax$i')),
            ]),
            axisBar(r.ax[i].a, r.ax[i].sc),
          ], gap: 4),
        Row(children: [
          Expanded(child: Btn('잘 통하는 말', () => open('say'), kind: BtnKind.ghost, dense: true)),
          const SizedBox(width: 8),
          Expanded(child: Btn('강점 · 살펴볼 점', () => open('st'), kind: BtnKind.ghost, dense: true)),
        ]),
        Wrap(alignment: WrapAlignment.spaceBetween, children: [
          linkBtn('검사 정보와 읽는 법', () => info(r)),
          if (store.demo == null) linkBtn('공유 · 다시 검사', () => open('next')),
        ]),
      ], gap: 10),
      for (var i = 0; i < r.ax.length; i++) 'ax$i': axisPage(r.ax[i]),
      'say': col([
        h2('${store.nm}에게 잘 통하는 말'),
        for (final x in r.ax) col([muted('${x.pole} 기질에게'), say(C.poles[x.letter]!.say)], gap: 4),
      ], gap: 14),
      'st': col([
        Row(children: [
          for (final (w, t) in const [(false, '타고난 강점'), (true, '살펴볼 점')]) ...[
            if (w) const SizedBox(width: 8),
            Expanded(
                child: GestureDetector(
                    onTap: () => setState(() => showWatch = w),
                    child: NineBox(showWatch == w ? nChipOn : nChip,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Center(child: Text(t, style: disp(17, color: showWatch == w ? kOnAccent : kMuted)))))),
          ],
        ]),
        for (final x in r.ax)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 5), child: Image.asset('assets/ui/dot_${x.a.c}.webp', width: 12, height: 12)),
            const SizedBox(width: 8),
            Expanded(child: Text(showWatch ? C.poles[x.letter]!.wa : C.poles[x.letter]!.st, style: body)),
          ]),
      ], gap: 14),
      'next': col([
        h2('이제 무엇을 할까요?'),
        Tile(kid.inv != null ? '${kid.inv!['from'] ?? '가족'}에게 결과 보내기' : '결과 카드 공유하기', icon: 'i_share', sub: '유형과 별명만 보냅니다', onTap: () => openShare(context, kid.inv != null ? '결과 보내기' : '결과 공유')),
        Tile('다른 양육자도 검사하기', icon: 'i_heart', sub: '서로 다르게 본 점을 비교해요', onTap: () => addWho(context, invite: () => inviteCg(context))),
        Tile('다시 검사하기', icon: 'i_retry', sub: '시간이 지나 달라진 점을 봅니다', onTap: () => startRetest(context)),
      ]),
    };
  }

  /// 예시 문장 속 '엄마'를 지금 답하는 양육자로 바꾼다(아빠·할머니·할아버지가 볼 때)
  String me(String t) => const ['아빠', '할머니', '할아버지'].contains(store.kid.who) ? t.replaceAll('엄마', store.kid.who) : t;

  /// 지표 옆 작은 평균 아이콘. 누르면 같은 나이·성별 아이들의 평균을 보여 준다.
  Widget avgBtn(String key, String name, int sc, String c, {String? lo, String? hi}) => InkWell(
        key: Key('avg-$key'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => avgPopup(key, name, sc, c, lo: lo, hi: hi),
        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 1), child: Icon(Icons.bar_chart_rounded, size: 19, color: kAccentInk)),
      );

  void avgPopup(String key, String name, int sc, String c, {String? lo, String? hi}) {
    final kid = store.kid, nm = store.nm, b = bucketOf(kid, store.cur.date);
    popup(context, title: '또래 평균 · $name', (ctx, set) {
      if (b == null) {
        return [
          Text('같은 나이, 같은 성별 아이들의 평균과 비교하려면 $nm의 ${kid.sex.isEmpty ? '성별' : '태어난 해와 달'}이 필요합니다.', style: small),
          Btn('아이 정보 넣기', () async {
            Navigator.of(ctx).pop();
            await editKid(context);
            if (mounted && bucketOf(store.kid, store.cur.date) != null) avgPopup(key, name, sc, c, lo: lo, hi: hi);
          }),
        ];
      }
      return [
        FutureBuilder(
            future: stats.load(b),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
              final all = snap.data, a = all?[key], label = bucketLabel(b);
              if (all == null) return const Text('평균을 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.', style: small);
              if (a == null || a.n < kStatMin) {
                return col([
                  rich('**$label 평균 준비 중.** 검사 결과가 $kStatMin건 이상 모이면 평균이 표시됩니다. 지금 ${a?.n ?? 0}건이 모였습니다.', style: small),
                  Row(children: [SizedBox(width: 72, child: Text(nm, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Track(sc, c, thin: true)), SizedBox(width: 36, child: Text('$sc', textAlign: TextAlign.right, style: disp(19)))]),
                ]);
              }
              final av = a.avg.round(), d = sc - av;
              final diff = d.abs() < 5
                  ? '$label 평균과 비슷합니다.'
                  : lo != null
                      ? '$label 평균보다 ${d.abs()}점 ${d > 0 ? hi : lo} 쪽입니다.'
                      : '$label 평균보다 ${d.abs()}점 ${d > 0 ? '높습니다' : '낮습니다'}.';
              Widget line(String t, int v, {bool ring = false}) => Row(children: [
                    SizedBox(width: 72, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: ring ? FontWeight.w500 : FontWeight.w700, fontSize: 14))),
                    Expanded(child: ring ? Track(null, c, thin: true, was: v) : Track(v, c, thin: true)),
                    SizedBox(width: 36, child: Text('$v', textAlign: TextAlign.right, style: disp(19))),
                  ]);
              return col([
                Align(alignment: Alignment.centerLeft, child: Tag('$label · ${a.n}건')),
                if (lo != null) Row(children: [const SizedBox(width: 72), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [muted(lo), muted(hi!)])), const SizedBox(width: 36)]),
                line(nm, sc),
                line('또래 평균', av, ring: true),
                Text(diff, style: body.copyWith(fontWeight: FontWeight.w700)),
                muted(lo != null ? '기질에는 좋고 나쁨이 없습니다. 평균과의 차이는 $nm의 개성입니다.' : '자라는 힘은 나이가 들수록 높아집니다. 평균은 이 앱으로 검사한 같은 나이 아이들의 값입니다.'),
              ]);
            }),
      ];
    });
  }

  Widget say(String t, {bool avoid = false}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: avoid ? kColors['c3']! : kAccent, width: 3))),
        child: Text('“${me(t)}”',
            style: avoid ? const TextStyle(fontSize: 13, color: kMuted, decoration: TextDecoration.lineThrough) : disp(18, w: FontWeight.w400)),
      );

  /// 축 상세: 막대·요약·말 가이드·세부 기질 3가지. 더 깊은 내용(상황별 말 4가지, 기질 설명)은 팝업창
  Widget axisPage(AxScore x) {
    final pl = C.poles[x.letter]!, bal = x.d < 8;
    return col([
      Row(children: [Expanded(child: Text('${x.a.hi} · ${x.a.lo}', style: disp(23))), Pill('${x.pole} ${x.clar}', x.a.c)]),
      axisBar(x.a, x.sc),
      Text(pl.sum, style: body),
      // 이렇게 말해 보세요: 크게 강조. 자세히 보기에서 상황 4가지
      NineBox(nPink,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
          child: col([
            Row(children: [
              Image.asset('assets/ui/i_bulb.webp', width: 30, height: 30),
              const SizedBox(width: 8),
              Expanded(child: Text('이렇게 말해 보세요', style: disp(24))),
            ]),
            Text('“${me(pl.say)}”', style: disp(20, w: FontWeight.w400)),
            Row(children: [const Expanded(child: Text('상황별 말 예시 4가지', style: smallMuted)), MoreBtn(() => popup(context, title: '이렇게 말해 보세요', icon: 'i_bulb', (c, set) => axisMore(x)))]),
          ], gap: 8)),
      Row(children: [
        Expanded(child: muted('세부 기질 · ${x.a.q}')),
        linkBtn(
            '기질 설명',
            () => popup(context, title: '${x.pole} 기질', (c, set) => [
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final t in pl.tags) Tag('#$t')]),
                  if (bal) rich('**균형에 가까움.** 상황에 따라 ${x.a.hi}, ${x.a.lo} 두 모습을 오가며, 굳이 나누면 ${x.pole} 쪽입니다.', style: small),
                  Text(pl.det, style: body),
                ])),
      ]),
      for (var i = 0; i < x.a.subs.length; i++) subRow(x.a, x.a.subs[i], x.subs[i], i),
    ], gap: 10);
  }

  /// 이렇게 말해 보세요 팝업: 상황 4가지와 그때 해 볼 말, 피하면 좋은 말
  List<Widget> axisMore(AxScore x) {
    final pl = C.poles[x.letter]!;
    return [
      Align(alignment: Alignment.centerLeft, child: Pill('${x.pole} 기질에게', x.a.c)),
      for (var i = 0; i < pl.says.length; i++)
        NineBox(nSoft,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: col([
              Text('${i + 1}. ${pl.says[i][0]}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kAccentInk)),
              Text('“${me(pl.says[i][1])}”', style: disp(19, w: FontWeight.w400)),
            ], gap: 3)),
      col([muted('이런 말은 피해 주세요'), say(pl.no, avoid: true)], gap: 4),
    ];
  }

  Widget subRow(Ax a, Sub s, int? sc, [int i = -1]) => sc == null
      ? col([Row(children: [Expanded(child: Text(s.n, style: const TextStyle(fontWeight: FontWeight.w700))), muted('정보 부족')]), muted("이 항목은 '잘 모르겠다'로 답한 문항이 많아 판단하지 않았습니다.")], gap: 2)
      : col([
          Row(children: [
            Flexible(flex: 0, child: Text(s.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (i >= 0) avgBtn('${a.id}$i', s.n, sc, a.c, lo: s.lo, hi: s.hi),
            const SizedBox(width: 4),
            Expanded(child: Text(sc < 40 ? s.lo : sc > 60 ? s.hi : '중간', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted)),
          ]),
          Track(sc, a.c, thin: true),
        ], gap: 4);

  // ---------- 성격 탭 ----------
  Map<String, Widget> growTab(Result r, void Function(String) open) {
    const lvName = ['지금 자라는 중', '고르게 자라는 중', '탄탄함'];
    return {
      'root': col([
        eyebrow('성격 결과'),
        h2('자라는 힘'),
        muted('기질은 타고나지만 끈기, 스스로 힘, 함께 힘은 경험으로 자랍니다. 나이가 어릴수록 낮게 나오는 것이 자연스럽습니다.'),
        for (var i = 0; i < r.gr.length; i++)
          col([
            Row(children: [
              Text(r.gr[i].g.n, style: disp(19)),
              if (r.gr[i].sc != null) avgBtn(r.gr[i].g.id, r.gr[i].g.n, r.gr[i].sc!, 'g'),
              const SizedBox(width: 4),
              Expanded(child: Text(r.gr[i].sc == null ? '정보 부족' : lvName[r.gr[i].lv!], style: smallMuted)),
              MoreBtn(() => open('g$i')),
            ]),
            if (r.gr[i].sc != null)
              Row(children: [
                Expanded(child: Track(r.gr[i].sc, 'g', fill: true)),
                SizedBox(width: 40, child: Text('${r.gr[i].sc}', textAlign: TextAlign.right, style: disp(20))),
              ]),
          ], gap: 4),
        Row(children: [Expanded(child: Text('지난번과 달라진 점', style: disp(19))), MoreBtn(() => open('cmp'))]),
      ], gap: 14),
      for (var i = 0; i < r.gr.length; i++)
        'g$i': () {
          final x = r.gr[i];
          return col([
            eyebrow('자라는 힘'),
            Row(children: [Expanded(child: h2(x.g.n)), if (x.sc != null) Pill(lvName[x.lv!], 'g')]),
            muted(x.g.d),
            if (x.sc == null)
              Note(const Text("'잘 모르겠다'로 답한 문항이 많아 판단하지 않았습니다."))
            else ...[
              Row(children: [
                Expanded(child: Track(x.sc, 'g', fill: true)),
                SizedBox(width: 40, child: Text('${x.sc}', textAlign: TextAlign.right, style: disp(20))),
              ]),
              Text(x.g.lv[x.lv!][0], style: body.copyWith(fontWeight: FontWeight.w700)),
              Text(x.g.lv[x.lv!][1], style: body),
            ],
          ]);
        }(),
      'cmp': cmpPage(r),
    };
  }

  Widget cmpPage(Result r) {
    final kid = store.kid, c = compareGrow(r, store.cur.prev, kid.who, store.cur.ans);
    const cmpv = [('비슷함', 'c2'), ('자랐음', 'c4'), ('낮아졌음', 'c1')];
    return col([
      eyebrow('이전 검사와 비교'),
      h2('지난번과 달라진 점'),
      if (c.p != null) muted('이전 검사 ${c.p!.date.isEmpty ? '날짜 없음' : c.p!.date} · 평가자 ${c.p!.who}${c.p!.sample ? ' · 샘플 예시 기록' : ''}'),
      if (c.none)
        rich("**비교 기록 없음.** 비교할 이전 점수가 남아 있지 않습니다. '다시 검사하기'를 하면 그 전 점수가 남아 이곳에 나란히 보입니다.", style: small)
      else if (c.otherWho)
        rich('**평가자가 달라 직접 비교하기 어렵습니다.** 이전 검사는 ${c.p!.who}, 이번 검사는 ${kid.who}가 답했습니다.', style: small)
      else ...[
        for (final o in c.rows) growRow(o, cmpv),
        muted("작은 점수 차이는 답하는 날의 기분이나 상황으로도 생기므로 '비슷함'으로 봅니다. 순위나 진단이 아니라 같은 평가자가 본 변화의 방향입니다."),
      ],
    ]);
  }

  Widget growRow(GrowCmpRow o, List<(String, String)> cmpv) => o.skip != null
      ? col([Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700)), muted("${o.skip}에서 '잘 모르겠다'가 절반 이상이라 비교하지 않았습니다.")], gap: 2)
      : Row(children: [
          SizedBox(width: 72, child: Text(o.x.g.n, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('이전 ${o.ps} → 지금 ${o.x.sc}', style: small)),
          Pill(cmpv[o.v!].$1, cmpv[o.v!].$2),
        ]);

  /// 긴 목록을 쪽으로 나눈다
  List<List<T>> chunk<T>(List<T> l, int n) => [for (var i = 0; i < l.length; i += n) l.sublist(i, min(i + n, l.length))];

  /// 해석 한 덩어리: 굵은 머리 + 본문 (+ 질문·조언 상자)
  Widget insight(String head, String text, {String? tip, String? tipLabel, Widget? right}) => col([
        Row(children: [Expanded(child: Text(head, style: disp(19))), if (right != null) right]),
        Text(text, style: small),
        if (tip != null) Note(rich('**${tipLabel ?? '함께 이야기해 보세요'}** $tip', style: small)),
      ], gap: 6);

  /// 숫자 한 칸(요약용)
  Widget stat(String n, String label) => Expanded(
      child: NineBox(nSoft,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(n, style: disp(24))),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kMuted)),
          ])));

  // ---------- 양육자 비교 탭 ----------
  Map<String, Widget> cgTab(void Function(String) open) {
    final kid = store.kid, nm = store.nm, all = kid.cgs, fin = all.where((e) => fullDone(e.value.ans)).toList();
    if (fin.length < 2) {
      return hub(open, const [''], [
        col([
          eyebrow('양육자 비교'),
          h2('양육자마다 다르게 본 점'),
          muted('같은 아이도 함께 지내는 시간과 장면이 달라 다르게 보일 수 있습니다.'),
          rich("**비교할 양육자가 아직 없습니다.** 정밀검사를 마친 양육자가 두 명 이상이면 일치도, 다르게 본 이유, 함께 정할 약속까지 이곳에 정리됩니다. 지금 마친 사람: ${fin.isEmpty ? '없음' : fin.map((e) => e.key).join(', ')}.", style: small),
          Tile('이 휴대폰에서 다른 양육자 검사', icon: 'i_heart', sub: '광고 1번 보고 무료', onTap: () => addWho(context, invite: () => inviteCg(context))),
          Tile('다른 휴대폰으로 초대 보내기', icon: 'i_share', sub: '결과를 보내 주면 이곳에 합쳐집니다', onTap: () => inviteCg(context)),
        ])
      ]);
    }
    final rs = [for (final e in fin) (who: e.key, rec: e.value, r: score(e.value.ans))];
    final codes = rs.map((x) => x.r.code).toSet();
    final axv = [
      for (var i = 0; i < C.axes.length; i++)
        () {
          final sc = rs.map((x) => x.r.ax[i].sc), letters = rs.map((x) => x.r.ax[i].letter).toSet(), range = sc.reduce(max) - sc.reduce(min);
          final split = letters.length > 1;
          return (a: C.axes[i], i: i, split: split, range: range, v: split ? ('시선이 갈림', 'c1') : range >= Cmp.same ? ('정도가 다름', 'c3') : ('비슷하게 봄', 'c2'));
        }()
    ];
    final splitAx = axv.where((x) => x.split).toList();
    final diffAx = axv.where((x) => x.split || x.range >= Cmp.same).toList(), sameAx = axv.where((x) => !x.split).toList();
    final summary = codes.length == 1
        ? '${rs.map((x) => x.who).join(', ')} 모두 **${codes.first} ${C.nick[codes.first]}**로 같은 유형이 나왔습니다.'
        : '${rs.map((x) => '${x.who}는 **${x.r.code}**').join(', ')}로 유형이 다르게 나왔습니다.';
    final summary2 = splitAx.isNotEmpty ? ' **${splitAx.map((x) => '${x.a.hi}·${x.a.lo}').join(', ')}** 축에서 방향이 갈렸고, 나머지 ${4 - splitAx.length}축은 같은 방향입니다.' : ' 네 축 모두 같은 방향으로 보았습니다.';
    // 문항별 답 차이
    final spreads = [
      for (final it in C.items)
        () {
          final a = rs.map((o) => o.rec.ans[it.id]).whereType<int>().where((x) => x > 0).toList();
          return (it: it, n: a.length, spread: a.length > 1 ? a.reduce(max) - a.reduce(min) : 0);
        }()
    ];
    final both = spreads.where((x) => x.n > 1).toList(), close = both.where((x) => x.spread <= 1).length;
    final agree = both.isEmpty ? null : (close * 100 / both.length).round();
    final split = spreads.where((x) => x.spread >= Cmp.gap).toList()..sort((x, y) => y.spread - x.spread);
    Widget qrow(Item it) => col([
          Text(it.t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Wrap(spacing: 12, children: [for (final o in rs) rich('**${o.who}** ${optName(o.rec.ans[it.id])}', style: small)]),
        ], gap: 2);
    // 세부 기질 12가지: 사람마다 점수 차
    final subv = [
      for (var ai = 0; ai < C.axes.length; ai++)
        for (var si = 0; si < C.axes[ai].subs.length; si++)
          () {
            final sc = [for (final o in rs) (who: o.who, s: o.r.ax[ai].subs[si])].where((x) => x.s != null).toList();
            if (sc.length < 2) return null;
            final hi = sc.reduce((a, b) => a.s! >= b.s! ? a : b), lo = sc.reduce((a, b) => a.s! <= b.s! ? a : b);
            return (a: C.axes[ai], s: C.axes[ai].subs[si], sc: sc, hi: hi, lo: lo, range: hi.s! - lo.s!);
          }()
    ].nonNulls.toList()
      ..sort((x, y) => y.range - x.range);
    final subFar = subv.where((x) => x.range >= Cmp.same).take(3).toList(), subNear = subv.reversed.where((x) => x.range < Cmp.same).take(3).toList();
    Widget subCmp(dynamic x) => col([
          Row(children: [Expanded(child: Text(x.s.n, style: const TextStyle(fontWeight: FontWeight.w700))), Text([for (final o in x.sc) '${o.who} ${o.s}'].join(' · '), style: small)]),
          for (final o in x.sc)
            Row(children: [
              SizedBox(width: 64, child: Text(o.who, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMuted))),
              Expanded(child: Track(o.s, x.a.c, thin: true)),
            ]),
          if (x.range >= Cmp.same) muted('${x.hi.who}는 ${x.s.hi} 쪽으로, ${x.lo.who}는 ${x.s.lo} 쪽으로 더 보았습니다.'),
        ], gap: 3);
    // 자라는 힘
    final grv = [
      for (var gi = 0; gi < C.grows.length; gi++)
        () {
          final sc = rs.map((o) => o.r.gr[gi].sc).toList(), ok = sc.whereType<int>().toList();
          return (g: C.grows[gi], sc: sc, range: ok.length > 1 ? ok.reduce(max) - ok.reduce(min) : null);
        }()
    ];
    final level = agree == null ? '' : agree >= 80 ? '매우 비슷하게 보고 있습니다' : agree >= 60 ? '대체로 비슷하게 보고 있습니다' : '서로 다른 장면을 많이 보고 있습니다';
    return hub(open, [
      '',
      '기질 4축, 사람마다',
      '다르게 본 이유와 대화',
      '세부 기질 비교',
      '자라는 힘, 사람마다',
      '함께 지키는 약속',
      '답이 크게 갈린 문항${split.isEmpty ? '' : ' ${split.length}'}',
    ], [
      col([
        eyebrow('양육자 비교 · ${rs.map((x) => x.who).join(', ')}'),
        rich(summary + summary2, style: small),
        Row(children: [
          stat(agree == null ? '-' : '$agree%', '답 일치도'),
          const SizedBox(width: 6),
          stat('${4 - splitAx.length}/4', '같은 방향 축'),
          const SizedBox(width: 6),
          stat('${split.length}', '크게 갈린 문항'),
        ]),
        if (agree != null) muted('함께 답한 ${both.length}문항 중 $close문항이 한 칸 이내로 같았습니다. $level.'),
      ], gap: 8),
      col([
        h2('기질 4축, 사람마다'),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final o in rs) Row(mainAxisSize: MainAxisSize.min, children: [mascot(o.r.code, size: 40), const SizedBox(width: 4), Flexible(child: rich('**${o.who}** ${o.r.code}', style: small))]),
        ]),
        for (final x in axv)
          col([
            Row(children: [Expanded(child: Text('${x.a.lo} ← → ${x.a.hi}', style: disp(18))), Pill(x.v.$1, x.v.$2)]),
            for (final o in rs)
              Row(children: [
                SizedBox(width: 64, child: Text(o.who, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                Expanded(child: Track(o.r.ax[x.i].sc, x.a.c, thin: true)),
                SizedBox(width: 44, child: Text('${o.r.ax[x.i].letter} ${o.r.ax[x.i].sc}', textAlign: TextAlign.right, style: small)),
              ]),
          ], gap: 4),
        linkBtn('읽는 법', () => popup(context, title: '읽는 법', (c, set) => [
              Text("점 위치는 0~100 점수입니다. 가운데 옅은 띠(40~60)는 균형 구간입니다. 방향(글자)이 다르면 '시선이 갈림', 같은 방향이어도 ${Cmp.same}점 넘게 벌어지면 '정도가 다름'으로 표시합니다.", style: small),
              Text('어느 쪽이 맞다는 뜻이 아니라, $nm${ga2(nm)} 사람과 상황에 따라 다른 모습을 보인다는 단서입니다.', style: small),
            ])),
      ], gap: 9),
      col([
        h2('다르게 본 이유와 대화'),
        if (diffAx.isEmpty)
          Text('네 축 모두 비슷하게 보았습니다. $nm${ga2(nm)} 누구 앞에서나 한결같은 모습을 보인다는 뜻이고, 양육자들이 아이를 같은 눈으로 보고 있다는 좋은 신호입니다. 같은 말과 같은 순서로 대해 주면 아이가 더 편안해합니다.', style: body)
        else
          for (final x in diffAx.take(2))
            insight('${x.a.hi} · ${x.a.lo}', '${rs.map((o) => '${o.who}는 ${o.r.ax[x.i].pole} ${o.r.ax[x.i].sc}').join(', ')}. ${cgWhy[x.a.id]}', tip: cgAsk[x.a.id], right: Pill(x.v.$1, x.v.$2)),
        if (diffAx.length > 2)
          Align(
              alignment: Alignment.centerLeft,
              child: linkBtn('나머지 ${diffAx.length - 2}개 축 더 보기', () => popup(context, title: '다르게 본 이유와 대화', (c, set) => [
                    for (final x in diffAx.skip(2)) insight('${x.a.hi} · ${x.a.lo}', '${rs.map((o) => '${o.who}는 ${o.r.ax[x.i].pole} ${o.r.ax[x.i].sc}').join(', ')}. ${cgWhy[x.a.id]}', tip: cgAsk[x.a.id]),
                  ]))),
      ], gap: 12),
      col([
        h2('세부 기질 비교'),
        muted('세부 기질 12가지 중 가장 다르게 본 것과 가장 비슷하게 본 것입니다.'),
        if (subFar.isNotEmpty) ...[eyebrow('가장 다르게 본 세부 기질'), for (final x in subFar) subCmp(x)] else const Text('크게 다르게 본 세부 기질이 없습니다.', style: small),
        if (subNear.isNotEmpty) ...[
          eyebrow('가장 비슷하게 본 세부 기질'),
          Text(subNear.map((x) => '${x.s.n}(${[for (final o in x.sc) '${o.s}'].join('·')})').join(', '), style: small),
        ],
      ], gap: 9),
      col([
        h2('자라는 힘, 사람마다'),
        for (final x in grv)
          col([
            Row(children: [
              SizedBox(width: 72, child: Text(x.g.n, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Text([for (var k = 0; k < rs.length; k++) '${rs[k].who} ${x.sc[k] ?? '판단 안 함'}'].join(' · '), style: small)),
              if (x.range != null) Pill(x.range! < Cmp.same ? '비슷하게 봄' : '정도가 다름', x.range! < Cmp.same ? 'c2' : 'c3'),
            ]),
            if (x.range != null && x.range! >= Cmp.same) muted(cgGrowWhy[x.g.id]!),
          ], gap: 4),
        if (grv.every((x) => x.range == null || x.range! < Cmp.same)) muted('자라는 힘은 모두 비슷하게 보았습니다. 끈기, 스스로 힘, 함께 힘은 경험으로 자라므로, 같은 기준으로 칭찬해 주면 더 빨리 자랍니다.'),
      ], gap: 12),
      col([
        h2('함께 지키는 약속'),
        for (var i = 0; i < cgPromises.length; i++) col([Text('${i + 1}. ${cgPromises[i].$1}', style: const TextStyle(fontWeight: FontWeight.w700)), muted(cgPromises[i].$2)], gap: 2),
        if (sameAx.isNotEmpty) ...[
          eyebrow('모두 같은 방향으로 본 기질 · 함께 쓸 말'),
          for (final x in sameAx.take(2)) col([muted('${rs.first.r.ax[x.i].pole} 기질에게'), say(C.poles[rs.first.r.ax[x.i].letter]!.say)], gap: 3),
        ],
      ], gap: 10),
      col([
        h2('답이 크게 갈린 문항'),
        if (split.isEmpty)
          Text('${Cmp.gap}칸 이상 벌어진 문항이 없습니다. 양육자들이 $nm${ga2(nm)} 꽤 비슷하게 보고 있습니다.', style: small)
        else ...[
          muted('${Cmp.gap}칸 이상 다른 답을 고른 문항 ${split.length}개 중 차이가 큰 순서입니다. 이 장면을 언제, 어디서 봤는지 서로 이야기해 보세요.'),
          for (final x in split.take(4)) qrow(x.it),
          if (split.length > 4)
            Align(alignment: Alignment.centerLeft, child: linkBtn('나머지 ${split.length - 4}문항 더 보기', () => popup(context, title: '답이 크게 갈린 문항', (c, set) => [for (final x in split.skip(4)) qrow(x.it)]))),
        ],
      ], gap: 12),
    ]);
  }

  // ---------- 달라진 점 탭 ----------
  Map<String, Widget> changeTab(Result r, void Function(String) open) {
    final kid = store.kid, cur = store.cur, pv = cur.prev;
    final head = [
      eyebrow('이전 검사와 비교 · ${kid.who}'),
      if (pv != null) muted('이전 ${pv.date.isEmpty ? '날짜 없음' : pv.date} → 이번 ${cur.date}${pv.sample ? ' · 샘플 예시 기록' : ''}'),
    ];
    if (pv == null) {
      return hub(open, const [''], [
        col([
          ...head,
          h2('다시 검사로 달라진 점'),
          rich("**비교 기록 없음.** ${kid.who}의 이전 검사 기록이 없습니다. 다시 검사하면 지금 결과가 이전 기록으로 남고, 유형·4축·세부 기질·자라는 힘이 어떻게 달라졌는지와 그 뜻을 정리해 드립니다.", style: small),
          muted('기질은 천천히 변하므로 3~6개월 간격으로 다시 검사하면 변화를 가장 잘 볼 수 있습니다.'),
          if (store.demo == null) Tile('다시 검사하기', icon: 'i_retry', sub: '시간이 지나 달라진 점을 봅니다', onTap: () => startRetest(context)),
        ])
      ]);
    }
    if (pv.who.isNotEmpty && pv.who != kid.who) {
      return hub(open, const [''], [
        col([...head, h2('다시 검사로 달라진 점'), rich("**평가자가 달라 직접 비교하기 어렵습니다.** 이전 검사는 ${pv.who}, 이번 검사는 ${kid.who}가 답했습니다. 양육자 사이의 차이는 '양육자 비교' 탭에서 볼 수 있습니다.", style: small)])
      ]);
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
        : ([
            for (final x in r.ax)
              for (var i = 0; i < x.a.subs.length; i++) (a: x.a, s: x.a.subs[i], ps: pv.sub![x.a.id]?[i], cs: x.subs[i])
          ].where((o) => o.ps != null && o.cs != null && (o.cs! - o.ps!).abs() >= Cmp.sub).toList()
            ..sort((a, b) => (b.cs! - b.ps!).abs() - (a.cs! - a.ps!).abs()));
    final pa = pv.ans, ca = cur.ans;
    final ch = pa == null ? <Item>[] : C.items.where((it) => pa[it.id] != null && ca[it.id] != null && pa[it.id] != ca[it.id]).toList();
    final big = ch.where((it) => pa![it.id]! > 0 && ca[it.id]! > 0 && (pa[it.id]! - ca[it.id]!).abs() >= Cmp.gap).toList()
      ..sort((a, b) => (pa![b.id]! - ca[b.id]!).abs() - (pa[a.id]! - ca[a.id]!).abs());
    final unkCh = ch.where((it) => pa![it.id] == 0 || ca[it.id] == 0).length;
    final sum = (pv.code == r.code ? '유형은 **${r.code} ${C.nick[r.code]}** 그대로입니다.' : '유형이 **${pv.code}**에서 **${r.code}**로 바뀌었습니다.') +
        (axr.isNotEmpty ? (moved.isNotEmpty ? ' 4축 중 **${moved.map((o) => '${o.x.a.hi}·${o.x.a.lo}').join(', ')}** 축이 움직였고, 나머지는 비슷합니다.' : ' 4축 모두 비슷합니다.') : '');
    Widget qrow(Item it) => col([
          Text(it.t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Wrap(spacing: 12, children: [rich('**이전** ${optName(pa![it.id])}', style: small), rich('**지금** ${optName(ca[it.id])}', style: small)]),
        ], gap: 2);
    Widget subRow2(dynamic o) => col([
          Row(children: [Expanded(child: Text(o.s.n, style: const TextStyle(fontWeight: FontWeight.w700))), Text('${o.ps} → ${o.cs}', style: small)]),
          Track(o.cs, o.a.c, thin: true, was: o.ps),
          muted('${o.cs! > o.ps! ? o.s.hi : o.s.lo} 쪽으로 ${(o.cs! - o.ps!).abs()}점 움직였습니다.'),
        ], gap: 3);
    final g = compareGrow(r, pv, kid.who, ca);
    const cmpv = [('비슷함', 'c2'), ('자랐음', 'c4'), ('낮아졌음', 'c1')];
    Widget typeMini(String label, String code, {bool faded = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (C.nick.containsKey(code)) Opacity(opacity: faded ? .6 : 1, child: mascot(code, size: 40)),
          const SizedBox(width: 4),
          Flexible(child: col([rich('$label **$code**', style: small), Text(C.nick[code] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kMuted))], gap: 0, x: CrossAxisAlignment.start)),
        ]);
    // 다음 검사까지 지켜볼 것
    final watch = [...moved.map((o) => '${o.x.a.hi}·${o.x.a.lo}'), ...subs.take(2).map((o) => '${o.s.n}')];
    dynamic top;
    for (final o in moved) {
      if (top == null || o.d.abs() > top.d.abs()) top = o;
    }
    return hub(open, [
      '',
      if (axr.isNotEmpty) '기질 4축 변화',
      if (axr.isNotEmpty) '변화가 뜻하는 것',
      if (pv.sub != null) '달라진 세부 기질${subs.isEmpty ? '' : ' ${subs.length}'}',
      if (g.rows.isNotEmpty) '자라는 힘 변화',
      if (pa != null) '답이 크게 바뀐 문항${big.isEmpty ? '' : ' ${big.length}'}',
      '다음 검사까지',
    ], [
      col([
        ...head,
        rich(sum, style: small),
        Row(children: [Expanded(child: typeMini('이전', pv.code, faded: true)), const SizedBox(width: 6), Expanded(child: typeMini('지금', r.code))]),
        Row(children: [
          stat('${moved.length}/4', '움직인 축'),
          const SizedBox(width: 6),
          stat('${subs.length}/12', '달라진 세부 기질'),
          const SizedBox(width: 6),
          stat(pa == null ? '-' : '${ch.length}', '바뀐 답'),
        ]),
      ], gap: 8),
      if (axr.isNotEmpty)
        col([
          h2('기질 4축 변화'),
          for (final o in axr)
            col([
              Row(children: [Expanded(child: Text('${o.x.a.hi} · ${o.x.a.lo}', style: const TextStyle(fontWeight: FontWeight.w700))), muted('${o.ps} → ${o.x.sc}  '), Pill(o.v.$1, o.v.$2)]),
              Row(children: [
                SizedBox(width: 44, child: Text(o.x.a.lo, style: small)),
                Expanded(child: Track(o.x.sc, o.x.a.c, thin: true, was: o.ps)),
                SizedBox(width: 44, child: Text(o.x.a.hi, textAlign: TextAlign.right, style: small)),
              ]),
            ], gap: 6),
          muted("빈 동그라미: 이전, 색 점: 지금. ${Cmp.same}점보다 작은 차이는 '비슷함'"),
          const Note(Text('두 검사 사이의 차이는 아이가 자란 모습일 수도, 답한 날의 기분이나 최근 일의 영향일 수도 있습니다.')),
        ], gap: 14),
      if (axr.isNotEmpty)
        col([
          h2('변화가 뜻하는 것'),
          if (moved.isEmpty)
            Text('네 축 모두 지난번과 비슷합니다. $chgStable 지금 쓰고 있는 말과 방식이 아이에게 잘 맞고 있다는 뜻이기도 합니다.', style: body)
          else
            for (final o in moved.take(2))
              insight('${o.x.a.hi} · ${o.x.a.lo}', chgMove[o.x.letter]!, tipLabel: '이렇게 말해 보세요', tip: '“${me(C.poles[o.x.letter]!.say)}”', right: Pill(o.v.$1, o.v.$2)),
          if (moved.length > 2)
            Align(
                alignment: Alignment.centerLeft,
                child: linkBtn('나머지 ${moved.length - 2}개 축 더 보기', () => popup(context, title: '변화가 뜻하는 것', (c, set) => [
                      for (final o in moved.skip(2)) insight('${o.x.a.hi} · ${o.x.a.lo}', chgMove[o.x.letter]!, tipLabel: '이렇게 말해 보세요', tip: '“${me(C.poles[o.x.letter]!.say)}”'),
                    ]))),
          if (moved.isNotEmpty && moved.length < 4) muted('나머지 ${4 - moved.length}개 축은 $chgStable'),
        ], gap: 12),
      if (pv.sub != null)
        col([
          h2('달라진 세부 기질'),
          if (subs.isEmpty)
            Text('세부 기질 12가지 모두 ${Cmp.sub}점 안쪽으로만 움직였습니다. 큰 변화 없이 안정적입니다.', style: small)
          else ...[
            muted('세부 기질 12가지 중 ${Cmp.sub}점 이상 움직인 ${subs.length}가지입니다. 많이 움직인 순서입니다.'),
            for (final o in subs.take(4)) subRow2(o),
            if (subs.length > 4)
              Align(alignment: Alignment.centerLeft, child: linkBtn('나머지 ${subs.length - 4}가지 더 보기', () => popup(context, title: '달라진 세부 기질', (c, set) => [for (final o in subs.skip(4)) subRow2(o)]))),
          ],
        ], gap: 10),
      if (g.rows.isNotEmpty)
        col([
          h2('자라는 힘 변화'),
          for (final o in g.rows)
            col([
              growRow(o, cmpv),
              if (o.skip == null) muted(o.v == 0 ? chgGrowSame : chgGrow[o.x.g.id]![o.v! - 1]),
            ], gap: 4),
        ], gap: 12),
      if (pa != null)
        col([
          h2('답이 크게 바뀐 문항'),
          muted('${C.items.length}문항 중 ${ch.length}문항의 답이 바뀌었고, 그중 ${Cmp.gap}칸 이상 바뀐 문항은 ${big.length}개입니다.${big.isEmpty ? '' : ' 이 장면에서 요즘 무엇이 달라졌는지 떠올려 보세요.'}'),
          for (final it in big.take(4)) qrow(it),
          if (big.length > 4)
            Align(alignment: Alignment.centerLeft, child: linkBtn('나머지 ${big.length - 4}문항 더 보기', () => popup(context, title: '답이 크게 바뀐 문항', (c, set) => [for (final it in big.skip(4)) qrow(it)]))),
          if (unkCh > 0) muted("'잘 모르겠다'로 바뀌었거나 '잘 모르겠다'에서 답이 생긴 문항이 $unkCh개 있습니다."),
        ], gap: 12),
      col([
        h2('다음 검사까지'),
        col([
          const Text('1. 지켜볼 것', style: TextStyle(fontWeight: FontWeight.w700)),
          muted(watch.isEmpty ? '큰 변화가 없었습니다. 새 기관, 이사, 동생처럼 환경이 바뀔 때 아이의 반응을 눈여겨봐 주세요.' : '${watch.join(', ')}. 이 모습이 계속되는지, 특정한 날에만 그런지 지켜봐 주세요.'),
        ], gap: 2),
        col([
          const Text('2. 해 볼 것', style: TextStyle(fontWeight: FontWeight.w700)),
          muted(top == null ? "기질 탭의 '이렇게 말해 보세요' 문장 중 하나를 골라 2주 동안 써 보세요." : "가장 크게 움직인 ${top.x.a.hi}·${top.x.a.lo} 축의 '이렇게 말해 보세요' 문장을 2주 동안 써 보세요."),
        ], gap: 2),
        col([
          const Text('3. 다시 검사할 때', style: TextStyle(fontWeight: FontWeight.w700)),
          muted('기질은 천천히 변하므로 3~6개월 뒤가 알맞습니다. 같은 사람이 답해야 변화를 정확히 볼 수 있습니다.'),
        ], gap: 2),
        if (store.demo == null) Tile('다시 검사하기', icon: 'i_retry', sub: '지금 결과가 이전 기록으로 남습니다', onTap: () => startRetest(context)),
      ], gap: 12),
    ]);
  }
}

/// 요약 화면('root')에서 '자세히 보기'로 들어가고 '이전'으로 돌아오는 묶음. 화면마다 카드 한 장.
class Drill extends StatefulWidget {
  final Map<String, Widget> Function(void Function(String) open) build;
  const Drill(this.build, {super.key});
  @override
  State<Drill> createState() => _DrillState();
}

class _DrillState extends State<Drill> {
  final path = <String>[];
  void open(String k) => setState(() => path.add(k));
  void back() => setState(() => path.removeLast());
  // 다른 메뉴로 가면 요약으로 되돌린다(뒤로 가기가 리포트에 붙잡히지 않게)
  void onTab() {
    if (tab.value != 1 && path.isNotEmpty) setState(path.clear);
  }

  @override
  void initState() {
    super.initState();
    tab.addListener(onTab);
  }

  @override
  void dispose() {
    tab.removeListener(onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.build(open);
    while (path.isNotEmpty && !pages.containsKey(path.last)) {
      path.removeLast();
    }
    final key = path.isEmpty ? 'root' : path.last;
    return PopScope(
      canPop: path.isEmpty,
      onPopInvokedWithResult: (did, _) {
        if (!did && path.isNotEmpty) back();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (path.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const Key('back'),
                onTap: back,
                child: NineBox(nChip,
                    padding: const EdgeInsets.fromLTRB(12, 7, 16, 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/ui/i_arrow_l.webp', width: 18, height: 18),
                      const SizedBox(width: 6),
                      const Text('이전', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kFg)),
                    ])),
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: c)),
            child: NineBox(nCard, key: ValueKey(key), padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: Fit(pages[key]!)),
          ),
        ),
      ]),
    );
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
