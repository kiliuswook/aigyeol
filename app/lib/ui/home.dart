// 홈: 한 화면. 인사 줄 · 아이 카드(지금 상태와 할 일 버튼) · 답하는 사람 · 바로 가기 세 칸.
// 앱 소개(타이틀)는 intro.dart 가 맡고, 홈은 '지금 무엇을 할까'만 보여 준다.
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';
import 'share.dart' show inviteCg, openShare;
import 'report.dart' show eun;
import 'setup.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  void newKid(BuildContext context) {
    store.addKid();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  /// 바로 가기 칸: 아이콘 + 이름
  Widget quick(String icon, String label, VoidCallback? onTap) => Expanded(
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
              opacity: onTap == null ? .5 : 1,
              child: NineBox(nSoft,
                  padding: const EdgeInsets.fromLTRB(6, 9, 6, 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/ui/$icon.webp', width: 26, height: 26),
                    const SizedBox(height: 3),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kFg))),
                  ])))));

  /// 순서 한 칸(처음 화면): 번호 + 할 일
  Widget stepCell(int n, String t, String d) => Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
            child: Center(child: Text('$n', style: disp(19, color: kOnAccent)))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kFg))),
        FittedBox(fit: BoxFit.scaleDown, child: Text(d, maxLines: 1, style: const TextStyle(fontSize: 12, color: kMuted))),
      ]));

  Widget header(String sub) => Row(children: [
        Image.asset('assets/img/mascot_child.webp', width: 40, height: 40),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('내 아이의 MBTI', style: disp(24)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted),
        ])),
      ]);

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur, ks = store.kids;
    final n = answered(cur.ans), full = fullDone(cur.ans);
    final fresh = ks.length <= 1 && kid.name.isEmpty && !kid.cgs.any((e) => e.value.hasAny);
    if (fresh) return welcome(context);

    final done = full && cur.paid;
    final r = done ? score(cur.ans) : null;
    final mainBtn = done
        ? Btn('리포트 보기', () => tab.value = 1, kind: BtnKind.dark)
        : cur.paid
            ? Btn('검사 이어서 하기 ($n/${C.items.length})', () => startFull(context), kind: BtnKind.dark)
            : Btn('광고 보고 무료로 검사 시작', () => startFull(context), kind: BtnKind.dark);
    final sub = done ? '${store.nm}의 결과가 준비됐어요' : cur.paid ? '검사를 이어서 해 볼까요?' : '${store.nm}${eun(store.nm)} 어떤 아이일까요?';

    return Frame(
      top: header(sub),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        chipRow([
          for (var i = 0; i < ks.length; i++)
            ChipBtn('${ks[i].label(i)}${fullDone(ks[i].cur.ans) ? ' · ${score(ks[i].cur.ans).code}' : ''}', on: ks[i].id == kid.id, onTap: () => store.setKid(ks[i].id)),
          ChipBtn('+ 아이 추가', onTap: () => newKid(context)),
        ]),
        const SizedBox(height: 8),
        // 아이 카드: 지금 상태와 할 일 버튼을 한 장에
        Expanded(
          child: NineBox(nCard,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text.rich(
                          TextSpan(style: body, children: [
                            TextSpan(text: store.nm, style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' · ${[if (kid.ageText.isNotEmpty) kid.ageText else '나이 미입력', if (kid.sex == 'M') '남자아이', if (kid.sex == 'F') '여자아이'].join(' · ')}', style: const TextStyle(color: kMuted)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  linkBtn('바꾸기', () => editKid(context)),
                ]),
                Expanded(child: r != null ? Image.asset('assets/img/t_${r.code}.webp', fit: BoxFit.contain) : Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/img/mascot_child.webp', fit: BoxFit.contain))),
                const SizedBox(height: 4),
                if (r != null) ...[
                  FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 40), const SizedBox(width: 10), Text(C.nick[r.code]!, style: disp(24))])),
                  Text('${kid.who}가 본 ${store.nm} · ${cur.date}', style: smallMuted),
                ] else if (cur.paid) ...[
                  Text('검사 중이에요', style: disp(26)),
                  const SizedBox(height: 6),
                  ProgressBar(n / C.items.length),
                  const SizedBox(height: 4),
                  Text('$n / ${C.items.length}문항 · 언제든 이어서 할 수 있어요', style: smallMuted),
                ] else ...[
                  Text.rich(TextSpan(style: disp(26), children: [TextSpan(text: '${store.nm}의 '), const TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), const TextSpan(text: '는?')]), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [const Tag('무료'), const Tag('66문항'), const Tag('약 10분')]),
                ],
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: mainBtn),
              ])),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('답하는 사람', style: smallMuted),
          const SizedBox(width: 10),
          Expanded(
              child: chipRow([
            for (final e in kid.cgs)
              ChipBtn('${e.key}${fullDone(e.value.ans) ? ' · ${score(e.value.ans).code}' : e.value.ans.isNotEmpty ? ' · ${answered(e.value.ans)}/${C.items.length}' : ''}', on: e.key == kid.who, onTap: () => store.setWho(e.key)),
            ChipBtn('+ 추가', onTap: () => addWho(context, invite: () => inviteCg(context))),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          quick('i_heart', '가족 초대', () => inviteCg(context)),
          const SizedBox(width: 6),
          if (done) quick('i_retry', '다시 검사', () => startRetest(context)) else quick('i_doc', '샘플 리포트', () => showSample(context)),
          const SizedBox(width: 6),
          quick('i_share', '결과 공유', done ? () => openShare(context, '결과 공유') : null),
        ]),
      ]),
    );
  }

  /// 처음 연 사람: 무엇을 하게 되는지 세 걸음과 시작 버튼
  Widget welcome(BuildContext context) => Frame(
        top: header('만 2~7세 · 부모가 답하는 기질·성격 검사'),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: NineBox(nCard,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Image.asset('assets/img/mascot_child.webp', fit: BoxFit.contain))),
                  FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(style: disp(27), children: const [TextSpan(text: '우리 아이 '), TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), TextSpan(text: ', 알아볼까요?')]))),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [const Tag('무료'), const Tag('66문항'), const Tag('약 10분')]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    stepCell(1, '아이 등록', '이름 · 생년월 · 성별'),
                    stepCell(2, '66문항 답하기', '평소 모습 그대로'),
                    stepCell(3, '리포트 받기', '기질 · 성격 · 또래 평균'),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: Btn('시작하기', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen())), kind: BtnKind.dark)),
                ])),
          ),
          const SizedBox(height: 8),
          Tile('샘플 리포트 먼저 보기', icon: 'i_doc', sub: '예시 아이 콩이의 리포트', onTap: () => showSample(context)),
        ]),
      );
}
