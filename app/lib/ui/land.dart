// 받은 링크 화면: 공동 양육자 초대장, 도착한 결과, 친구네 유형, 앱 추천
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';
import 'links.dart';

class LandScreen extends StatefulWidget {
  final Landing l;
  const LandScreen(this.l, {super.key});
  @override
  State<LandScreen> createState() => _LandScreenState();
}

class _LandScreenState extends State<LandScreen> {
  String role = '';

  @override
  Widget build(BuildContext context) {
    final l = widget.l, d = l.d ?? {};
    List<Widget> body;
    if (l.kind == 'inv') {
      final n = '${d['n'] ?? ''}'.isEmpty ? tr('우리 아이') : '${d['n']}', f = '${d['f'] ?? tr('가족')}';
      final roles = {'${d['w'] ?? ''}', ...kCgl}.where((x) => x.isNotEmpty && x != f).toList();
      if (!roles.contains(role)) role = roles.first;
      body = [
        PaperCard([
          eyebrow(tr('초대장')),
          h1(tr('{0} {1} 기질검사에 초대했어요', [ga(cg(f)), n])),
          p(tr("{0}{1}를 떠올리며 66문항에 답하면, {2}가 본 결과와 나란히 비교할 수 있습니다. 서로의 답은 보이지 않으니 내 눈에 보이는 모습대로 답해 주세요.", [n, '${d['a'] ?? ''}'.isEmpty ? '' : '(${ageTx('${d['a']}')})', cg(f)])),
          muted(tr('나는')),
          chips([for (final x in roles) ChipBtn(cg(x), on: role == x, onTap: () => setState(() => role = x))]),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(tr('무료'), style: disp(34)),
            const SizedBox(width: 8),
            Text(tr('광고 1번 보고 검사'), style: smallMuted),
          ]),
          Btn(tr('검사 시작하기'), () {
            store.joinInvite(d, role);
            Navigator.of(context).pop();
            startFull(context);
          }),
          muted(tr('다 마치면 결과를 {0}에게 보내는 버튼이 나옵니다.', [cg(f)])),
        ])
      ];
    } else if (l.kind == 'res') {
      final ans = Store.decA('${d['x']}'), r = fullDone(ans) ? score(ans) : null, k = store.kidByKey('${d['k']}');
      final w = '${d['w'] ?? tr('가족')}';
      body = [
        PaperCard([
          eyebrow(tr('도착한 검사 결과')),
          h1(tr('{0} 본 {1}', [ga(cg(w)), '${d['n'] ?? ''}'.isEmpty ? tr('우리 아이') : d['n']])),
          if (r != null) ...[Center(child: mascot(r.code, size: 110)), Center(child: codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 44)), Center(child: h3(C.nick[r.code]!))]
          else muted(tr('아직 다 답하지 않은 결과입니다({0}/{1}).', [answered(ans), C.items.length])),
          muted(k != null ? tr("이 휴대폰의 {0} 기록에 {1}의 결과로 합칩니다. 리포트의 '양육자 비교'에서 나란히 볼 수 있습니다.", [k.name.isEmpty ? tr('아이') : k.name, w]) : tr('이 휴대폰에 같은 아이가 없어 새 아이로 추가합니다.')),
          Btn(k != null ? tr('합쳐서 비교 보기') : tr('새 아이로 추가하기'), () {
            store.mergeResult(d);
            tab.value = 1;
            Navigator.of(context).pop();
          }),
        ])
      ];
    } else if (l.kind == 'type') {
      final c = l.code!;
      body = [
        PaperCard([
          eyebrow(tr('친구네 아이의 MBTI')),
          Center(child: mascot(c, size: 120)),
          Center(child: Text(c, style: disp(48))),
          Center(child: h1(C.nick[c]!)),
          Text(tr('{0}입니다.', [c.split('').map((x) => C.poles[x]!.ph).join(', ')]), textAlign: TextAlign.center, style: smallMuted),
        ]),
        Cta([
          h2(tr('우리 아이는 어떤 네 글자일까요?'), color: kBg),
          Text(tr('만 2~7세, 부모가 답하는 66문항 기질검사. 광고 1번 보고 무료.'), style: const TextStyle(color: kBg)),
          Btn(tr('우리 아이 검사하기'), () {
            tab.value = 0;
            Navigator.of(context).pop();
          }),
        ]),
      ];
    } else {
      body = [
        Cta([
          h2(tr('우리 아이의 MBTI는 무엇일까요?'), color: kBg),
          Text(tr('친구가 추천한 영유아 기질검사입니다. 부모가 답하는 66문항, 광고 1번 보고 무료.'), style: const TextStyle(color: kBg)),
          Btn(tr('우리 아이 검사하기'), () {
            tab.value = 0;
            Navigator.of(context).pop();
          }),
        ])
      ];
    }
    return Scaffold(body: SafeArea(child: Frame(top: TopBar(tr('받은 링크'), close: true), body: Fit(align: Alignment.center, col(body, gap: 14)))));
  }
}
