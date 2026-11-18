// 홈: 한 화면. 아이 고르기 · 아이 카드(지금 상태) · 답하는 사람 · 지금 할 일 버튼 하나
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';
import 'setup.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void sample() {
    store.sample();
    tab.value = 1;
  }

  void newKid(BuildContext context) {
    store.addKid();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur, ks = store.kids;
    final n = answered(cur.ans), full = fullDone(cur.ans), pr = kid.nextPrice;
    final fresh = ks.length <= 1 && kid.name.isEmpty && !kid.cgs.any((e) => e.value.hasAny);
    if (fresh) return welcome(context);

    final done = full && cur.paid;
    final r = done ? score(cur.ans) : null;
    final mainBtn = done
        ? Btn('리포트 보기', () => tab.value = 1, kind: BtnKind.dark)
        : cur.paid
            ? Btn('검사 이어서 하기 ($n/${C.items.length})', () => startFull(context), kind: BtnKind.dark)
            : Btn('${Price.fmt(pr)} 결제하고 검사 시작', () => startFull(context), kind: BtnKind.dark);

    return Frame(
      top: Row(children: [
        Image.asset('assets/img/mascot_child.webp', width: 32, height: 32),
        const SizedBox(width: 8),
        Text('내 아이의 MBTI', style: disp(22)),
      ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        chipRow([
          for (var i = 0; i < ks.length; i++)
            ChipBtn('${ks[i].label(i)}${fullDone(ks[i].cur.ans) ? ' · ${score(ks[i].cur.ans).code}' : ''}', on: ks[i].id == kid.id, onTap: () => store.setKid(ks[i].id)),
          ChipBtn('+ 아이 추가', onTap: () => newKid(context)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: NineBox(nCard,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text.rich(
                          TextSpan(style: body, children: [
                            TextSpan(text: store.nm, style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' · ${kid.age.isEmpty ? '연령 미입력' : kid.age}', style: const TextStyle(color: kMuted)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  linkBtn('바꾸기', () => editKid(context)),
                ]),
                Expanded(child: r != null ? Image.asset('assets/img/t_${r.code}.webp', fit: BoxFit.contain) : Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/img/mascot_child.webp', fit: BoxFit.contain))),
                const SizedBox(height: 6),
                if (r != null) ...[
                  codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 44),
                  Text(C.nick[r.code]!, style: disp(24)),
                  Text('${kid.who}가 본 ${store.nm} · ${cur.date}', style: smallMuted),
                ] else if (cur.paid) ...[
                  Text('검사 중이에요', style: disp(26)),
                  const SizedBox(height: 8),
                  ProgressBar(n / C.items.length),
                  const SizedBox(height: 4),
                  Text('$n / ${C.items.length}문항 · 언제든 이어서 할 수 있어요', style: smallMuted),
                ] else ...[
                  Text.rich(TextSpan(style: disp(26), children: [TextSpan(text: '${store.nm}의 '), const TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), const TextSpan(text: '는?')]), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [Tag(kid.firstDone ? '추가 검사 ${Price.fmt(pr)}' : '첫 검사 ${Price.fmt(pr)}'), const Tag('66문항'), const Tag('약 10분')]),
                ],
              ])),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Text('답하는 사람', style: smallMuted),
          const SizedBox(width: 10),
          Expanded(
              child: chipRow([
            for (final e in kid.cgs)
              ChipBtn('${e.key}${fullDone(e.value.ans) ? ' · ${score(e.value.ans).code}' : e.value.ans.isNotEmpty ? ' · ${answered(e.value.ans)}/${C.items.length}' : ''}', on: e.key == kid.who, onTap: () => store.setWho(e.key)),
            ChipBtn('+ 추가', onTap: () => addWho(context, invite: () => tab.value = 2)),
          ])),
        ]),
      ]),
      foot: [
        mainBtn,
        if (done)
          Row(children: [
            Expanded(child: Btn('가족 초대·공유', () => tab.value = 2, kind: BtnKind.ghost, dense: true)),
            const SizedBox(width: 8),
            Expanded(child: Btn('다시 검사 · ${Price.fmt(Price.more)}', () => startRetest(context), kind: BtnKind.ghost, dense: true)),
          ])
        else
          Btn('샘플 리포트 먼저 보기', sample, kind: BtnKind.ghost),
      ],
    );
  }

  /// 처음 연 사람: 그림 한 장과 시작 버튼
  Widget welcome(BuildContext context) => Frame(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/img/key_home.webp', fit: BoxFit.cover, alignment: const Alignment(0, .38)),
                Positioned(left: 14, top: 14, child: NineBox(nChip, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('오늘도 말랑하게, 우리 아이 이야기', style: disp(17)))),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          eyebrow('만 2~7세 · 부모가 답하는 기질검사'),
          const SizedBox(height: 4),
          Text.rich(TextSpan(style: disp(30), children: const [TextSpan(text: '우리 아이의 '), TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), TextSpan(text: '는 무엇일까요?')])),
          const SizedBox(height: 4),
          muted('66문항 · 약 10분 · 네 글자 유형과 정밀 리포트'),
        ]),
        foot: [
          Btn('시작하기', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen())), kind: BtnKind.dark),
          Btn('샘플 리포트 먼저 보기', sample, kind: BtnKind.ghost),
        ],
      );
}
