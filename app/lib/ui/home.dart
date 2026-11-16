// 홈: 우리 아이(자녀 고르기·추가), 답하는 사람, 양육자별 검사 현황, 정밀검사 카드, 공유 안내, 기록 파일
import 'package:material_ui/material_ui.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';
import 'links.dart';
import 'pay.dart';

const kAges = ['', '만 2세', '만 3세', '만 4세', '만 5세', '만 6세', '만 7세'];

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final name = TextEditingController();
  String shownKid = '';

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur;
    if (shownKid != kid.id) {
      shownKid = kid.id;
      name.text = kid.name;
    }
    final n = answered(cur.ans), full = fullDone(cur.ans), pr = kid.nextPrice;
    final ks = store.kids;
    return AppPage([
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/img/key_home.webp', fit: BoxFit.cover, alignment: const Alignment(0, .16)),
            Positioned(left: 14, top: 14, child: NineBox(nChip, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('오늘도 말랑하게, 우리 아이 이야기', style: disp(17)))),
          ]),
        ),
      ),
      col([
        eyebrow('만 2~7세 · 부모가 답하는 기질검사'),
        Text.rich(TextSpan(style: disp(30), children: const [TextSpan(text: '우리 아이의 '), TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), TextSpan(text: '는 무엇일까요?')])),
        p('MBTI처럼 네 글자로 읽는 아이 기질 유형. 최근 한 달간 아이의 모습을 떠올리며 답해 주세요.', style: const TextStyle(color: kMuted, fontSize: 15, height: 1.6)),
      ], gap: 6),
      PaperCard([
        Row(children: [Expanded(child: h2('우리 아이')), if (ks.length > 1) muted('아이 ${ks.length}명')]),
        chips([
          if (ks.length > 1 || kid.name.isNotEmpty || n > 0)
            for (var i = 0; i < ks.length; i++)
              ChipBtn('${ks[i].label(i)}${fullDone(ks[i].cur.ans) ? ' · ${score(ks[i].cur.ans).code}' : ''}', on: ks[i].id == kid.id, onTap: () => store.setKid(ks[i].id)),
          ChipBtn('+ 아이 추가', onTap: () {
            store.addKid();
            toast(context, '새 아이를 추가했습니다. 이름과 연령을 넣어 주세요.');
          }),
        ]),
        Row(children: [
          Expanded(
              flex: 3,
              child: col([const Text('아이 이름 또는 별명 (선택)', style: smallMuted), PaperField(name, hint: '예: 콩이', onChanged: (v) => store.setInfo(name: v))], gap: 4)),
          const SizedBox(width: 10),
          Expanded(
              flex: 2,
              child: col([
                const Text('연령', style: smallMuted),
                NineBox(nInput,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: kAges.contains(kid.age) ? kid.age : '',
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [for (final a in kAges) DropdownMenuItem(value: a, child: Text(a.isEmpty ? '선택' : a))],
                      onChanged: (v) => store.setInfo(age: v ?? ''),
                    )),
              ], gap: 4)),
        ]),
        col([
          const Text('답하는 사람', style: smallMuted),
          NineBox(nInput,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                value: kid.who,
                isExpanded: true,
                underline: const SizedBox(),
                items: [for (final a in kid.names) DropdownMenuItem(value: a, child: Text(a))],
                onChanged: (v) => store.setWho(v ?? kid.who),
              )),
        ], gap: 4),
        muted(
            "${ks.length > 1 ? '아이마다 따로 검사하고 따로 저장됩니다. 위에서 아이를 눌러 바꿔 보세요. ' : "동생이나 형제가 있으면 '+ 아이 추가'로 따로 검사할 수 있습니다. "}엄마, 아빠, 할머니처럼 양육자마다 따로 답하면 리포트의 '양육자 비교'에서 서로 다르게 본 점을 정리해 드립니다."),
        if (kid.cgs.any((e) => e.value.ans.isNotEmpty || e.value.prev != null)) cgStatus(),
      ]),
      PaperCard([
        Align(alignment: Alignment.centerLeft, child: Tag(kid.firstDone ? '추가 검사' : '첫 검사')),
        h2('${store.nm}의 MBTI 정밀검사'),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(Price.fmt(pr), style: disp(36)),
          const SizedBox(width: 8),
          Text('검사 1회 · ${kid.who}', style: smallMuted),
        ]),
        for (final t in const ['66문항, 약 10분', '기질 결과: 네 글자 유형과 별명, 4축, 세부 기질 12가지, 잘 통하는 말', '성격 결과: 끈기, 스스로 힘, 함께 힘', '양육자 비교, 다시 검사하면 달라진 점 리포트'])
          Text('· $t', style: small),
        full && cur.paid
            ? Btn('${kid.who}의 리포트 보기', () => tab.value = 1, kind: BtnKind.dark)
            : cur.paid
                ? Btn('정밀검사 이어서 하기 ($n/${C.items.length})', () => startFull(context), kind: BtnKind.dark)
                : Btn('${Price.fmt(pr)} 결제하고 검사 시작', () => startFull(context), kind: BtnKind.dark),
        Btn('샘플 리포트 보기', () {
          store.sample();
          tab.value = 1;
        }, kind: BtnKind.ghost),
        priceNote(),
      ]),
      PaperCard([
        Row(children: [Image.asset('assets/ui/i_share.webp', width: 40, height: 40), const SizedBox(width: 10), Expanded(child: h2('함께 보면 더 잘 보여요'))]),
        muted('다른 휴대폰의 아빠, 할머니도 따로 검사하게 초대하거나 친구·가족에게 알려 주세요.'),
        Btn('공유하기', () => tab.value = 2, kind: BtnKind.ghost),
      ]),
      PaperCard([
        Fold(
            '휴대폰을 바꾸거나 앱을 지울 때',
            col([
              muted('검사 기록과 결제한 검사는 이 휴대폰 안에만 저장됩니다. 지우기 전에 기록 파일을 저장해 두고, 새 휴대폰에서 불러오면 그대로 이어집니다.'),
              Row(children: [
                Expanded(child: Btn('기록 파일 저장', () => saveBackup(context), kind: BtnKind.ghost)),
                const SizedBox(width: 10),
                Expanded(child: Btn('기록 불러오기', () => loadBackup(context), kind: BtnKind.ghost)),
              ]),
            ], gap: 10)),
      ]),
      muted('시제품입니다. 결제는 연결되어 있지 않아 결제 버튼을 누르면 바로 검사가 열립니다. 이 검사는 양육 참고용이며 의학적 진단이 아닙니다.'),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: openPrivacy, child: const Text('개인정보처리방침'))),
    ]);
  }

  /// 양육자별 검사 현황
  Widget cgStatus() {
    final kid = store.kid;
    return col([
      muted('양육자별 검사 현황'),
      for (final e in kid.cgs.where((e) => e.value.ans.isNotEmpty || e.value.prev != null))
        () {
          final code = fullDone(e.value.ans) ? score(e.value.ans).code : null, n = answered(e.value.ans);
          return Row(children: [
            code != null ? mascot(code, size: 40) : Opacity(opacity: .5, child: Image.asset('assets/img/mascot_child.webp', width: 40, height: 40)),
            const SizedBox(width: 10),
            Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (e.key == kid.who) ...[const SizedBox(width: 6), const Tag('지금 답하는 사람')],
            const Spacer(),
            Flexible(
                child: Text('${code != null ? '$code ${C.nick[code]}' : '정밀 $n/${C.items.length}'}${e.value.prev != null ? ' · 다시 검사함' : ''}${e.value.recv ? ' · 받은 결과' : ''}',
                    textAlign: TextAlign.right, style: smallMuted)),
          ]);
        }(),
    ], gap: 8);
  }
}
