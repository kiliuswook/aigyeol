// 형제 궁합 리포트(리포트의 '형제' 탭): 검사를 마친 두 아이의 4축을 견주어
// 궁합 이름, 축별 같음·다름, 함께할 놀이, 자주 부딪히는 상황(상황 카드로), 아이마다 다른 칭찬을 보여 준다.
// 문장은 assets/data/daily.json 의 sib(축마다 hh·ll·mix 3묶음 = 12묶음으로 256조합). AI 호출 없음.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../content.dart';
import '../daily.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'today.dart' show sitPopup;

/// 비교할 다른 아이(id). 비어 있으면 검사를 마친 첫 번째 다른 아이.
final sibOther = ValueNotifier<String>('');

typedef Hub = Map<String, Widget> Function(void Function(String) open, List<String> titles, List<Widget> pages);

String _nm(Kid k, int i) => k.label(i);

/// 축 하나의 비교: 경우(hh/ll/mix)와 두 아이 글자
({Ax a, String key, String la, String lb, SibAx t}) _axCmp(int i, Result ra, Result rb) {
  final a = C.axes[i], la = ra.ax[i].letter, lb = rb.ax[i].letter;
  final key = la != lb ? 'mix' : la == a.h ? 'hh' : 'll';
  return (a: a, key: key, la: la, lb: lb, t: D.sib.axes[a.id]![key]!);
}

/// 만 8세 이상이면 검사 대상(만 2~7세) 밖이라는 안내가 필요
bool _over(Kid k) {
  final m = RegExp(r'만 (\d+)세').firstMatch(k.ageText);
  return m != null && int.parse(m.group(1)!) >= 8;
}

Map<String, Widget> sibTab(BuildContext context, void Function(String) open, Hub hub) {
  final ks = store.kids, me = store.kid;
  final ra = kidResult(me);
  final others = [for (var i = 0; i < ks.length; i++) if (ks[i].id != me.id) (i: i, k: ks[i], r: kidResult(ks[i]))];
  final ready = others.where((o) => o.r != null).toList();
  final meI = ks.indexWhere((k) => k.id == me.id);
  final meN = _nm(me, meI);

  if (ra == null || ready.isEmpty) {
    final wait = [if (ra == null) meN, for (final o in others) if (o.r == null) _nm(o.k, o.i)];
    return hub(open, const [''], [
      col([
        eyebrow('형제 궁합'),
        h2('우리 집 아이들, 얼마나 닮았을까?'),
        muted('두 아이 모두 정밀검사를 마치면 닮은 점과 다른 점, 함께하면 좋은 놀이, 자주 부딪히는 상황과 대처, 아이마다 다르게 칭찬하는 법을 보여 드려요.'),
        rich('**아직 검사가 남은 아이:** ${wait.join(', ')}', style: small),
        if (others.isEmpty) muted('홈에서 \'+ 아이 추가\'로 형제·자매를 등록해 주세요.'),
      ])
    ]);
  }

  final pick = ready.firstWhere((o) => o.k.id == sibOther.value, orElse: () => ready.first);
  final kb = pick.k, rb = pick.r!, bN = _nm(kb, pick.i);
  final cmp = [for (var i = 0; i < C.axes.length; i++) _axCmp(i, ra, rb)];
  final same = cmp.where((x) => x.key != 'mix').length;
  final lv = D.sib.level[same];

  Widget face(String code, String name) => Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        mascot(code, size: 72),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kFg)),
        Text('$code · ${C.nick[code]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kMuted)),
      ]));

  Widget axRow(({Ax a, String key, String la, String lb, SibAx t}) x) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 66, child: Text('${x.a.hi}·${x.a.lo}', style: const TextStyle(fontSize: 13, color: kMuted))),
          Expanded(child: Text(poleName(x.la), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: x.a.color))),
          SizedBox(width: 40, child: Text(x.key == 'mix' ? '다름' : '같음', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: x.key == 'mix' ? kColors['c1'] : kColors['c2']))),
          Expanded(child: Text(poleName(x.lb), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: x.a.color))),
        ]),
      );

  // 함께할 놀이: 같은 축부터, 겹치지 않게 3개
  final plays = <String>[];
  for (final x in [...cmp.where((x) => x.key != 'mix'), ...cmp.where((x) => x.key == 'mix')]) {
    for (final p in x.t.play) {
      if (plays.length < 3 && !plays.contains(p)) plays.add(p);
    }
  }
  // 자주 부딪히는 상황: 다른 축 먼저, 3개
  final clashes = [...cmp.where((x) => x.key == 'mix'), ...cmp.where((x) => x.key != 'mix')].take(3).toList();
  final sits = {for (final x in clashes) x.t.sit, 's11'};

  // 휴대폰 공유 창(카카오톡 포함)으로 글+앱 주소
  void share() => SharePlus.instance.share(ShareParams(
      subject: '내 아이의 MBTI · 형제 궁합',
      text: '$meN ${ra.code} ${C.nick[ra.code]} × $bN ${rb.code} ${C.nick[rb.code]}\n우리 집은 "${lv[0]}"! ${lv[1]}\n우리 아이들 MBTI 궁합 보기 $kSite'));

  final root = col([
    if (ready.length > 1)
      chipRow([for (final o in ready) ChipBtn('$meN × ${_nm(o.k, o.i)}', on: o.k.id == kb.id, onTap: () => sibOther.value = o.k.id)]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      face(ra.code, meN),
      Padding(padding: const EdgeInsets.only(top: 24), child: Text('×', style: disp(28, color: kMuted))),
      face(rb.code, bN),
    ]),
    Center(child: Text(lv[0], style: disp(28, color: kAccentInk))),
    Text(lv[1], textAlign: TextAlign.center, style: small),
    NineBox(nSoft, padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: Column(mainAxisSize: MainAxisSize.min, children: [for (final x in cmp) axRow(x)])),
    if (_over(me) || _over(kb)) muted('검사는 만 2~7세 기준이에요. 만 8세 이상 아이의 결과는 참고로만 봐 주세요.'),
  ], gap: 8);

  final pGood = col([
    eyebrow('잘 맞는 점'),
    for (final x in cmp)
      rich('**${x.a.hi}·${x.a.lo}** ${x.t.good}', style: small),
    eyebrow('함께하면 좋은 놀이'),
    for (final p in plays) Row(children: [Image.asset('assets/ui/i_star.webp', width: 18, height: 18), const SizedBox(width: 8), Expanded(child: Text(p, style: body))]),
  ], gap: 8);

  final pClash = col([
    eyebrow('자주 부딪히는 상황'),
    for (final x in clashes)
      NineBox(nSoft,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: col([
            Text('${x.a.hi}·${x.a.lo} · ${x.key == 'mix' ? '서로 달라서' : '둘이 같아서'}', style: disp(18)),
            Text(x.t.clash, style: small),
            Text.rich(TextSpan(style: small, children: [const TextSpan(text: '이렇게 해 보세요  ', style: TextStyle(fontWeight: FontWeight.w700, color: kAccentInk)), TextSpan(text: x.t.tip)])),
          ], gap: 4)),
    eyebrow('이럴 땐 상황 카드'),
    for (final id in sits)
      Tile(D.situations.firstWhere((s) => s.id == id).t, icon: 'i_chat', onTap: () => sitPopup(context, me, D.situations.firstWhere((s) => s.id == id))),
  ], gap: 8);

  final pPraise = col([
    eyebrow('아이마다 다르게 칭찬하기'),
    muted('같은 일을 해도 아이마다 와닿는 말이 달라요. 둘을 견주는 말 대신 각자의 방식을 알아봐 주세요.'),
    for (final x in cmp)
      NineBox(x.key == 'mix' ? nPink : nSoft,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: col([
            Text('${x.a.hi}·${x.a.lo}${x.key == 'mix' ? ' · 서로 달라요' : ' · 같아요'}', style: disp(18)),
            Text.rich(TextSpan(style: small, children: [TextSpan(text: '$meN에게  ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: D.sib.praise[x.la])])),
            if (x.key == 'mix') Text.rich(TextSpan(style: small, children: [TextSpan(text: '$bN에게  ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: D.sib.praise[x.lb])])),
          ], gap: 4)),
    Btn('형제 궁합 공유하기', share, kind: BtnKind.dark),
  ], gap: 8);

  return hub(open, const ['', '잘 맞는 점과 함께할 놀이', '자주 부딪히는 상황', '아이마다 다르게 칭찬하기'], [root, pGood, pClash, pPraise]);
}
