// 홈: 한 화면. 인사 줄 · 아이 고르기(첫째·둘째 … + 아이 추가) · 고른 아이 카드(기본 정보 + 기질·성격 / 성장 발달 / 오늘 요약, 누르면 그 탭으로) · 바로 가기.
// 아이는 홈에서만 고른다. 다른 탭은 고른 아이로 진행되고 제목 옆 이름을 누르면 홈으로 온다.
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../daily.dart';
import '../dev.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';
import 'share.dart' show enterCode, inviteCg, openShare;
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
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
            child: Center(child: Text('$n', style: disp(19, color: kOnAccent)))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(t, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kFg))),
        FittedBox(fit: BoxFit.scaleDown, child: Text(d, maxLines: 1, style: const TextStyle(fontSize: 12, color: kMuted))),
      ])));

  Widget header(String sub) => Row(children: [
        Image.asset('assets/img/mascot_child.webp', width: 40, height: 40),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr('내 아이의 MBTI'), style: disp(24)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted),
        ])),
      ]);

  /// 아이 한 명의 바로 가기: 그 아이를 고르고 해당 탭으로
  void go(String id, int t) {
    store.setKid(id);
    tab.value = t;
  }

  /// 아이 카드 안의 한 줄: 영역 이름 · 지금 상태 · 화살표 (누르면 그 탭으로)
  Widget line(Key key, String icon, String label, String value, VoidCallback onTap, {Color? color}) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: NineBox(nSoft,
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            child: Row(children: [
              Image.asset('assets/ui/$icon.webp', width: 20, height: 20),
              const SizedBox(width: 6),
              SizedBox(width: isKo ? 66 : 92, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kFg))),
              Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: color == null ? FontWeight.w500 : FontWeight.w700, color: color ?? kMuted))),
              const SizedBox(width: 4),
              Image.asset('assets/ui/i_tri.webp', width: 11, height: 11),
            ])),
      );

  /// 기질·성격 한 줄: 유형과 별명 / 검사 중 / 아직. big 이면 유형은 그림 아래에 크게 있으니 누가 언제 본 결과인지
  (String, Color?) tempLine(Kid k, int i, {bool big = false}) {
    if (fullDone(k.cur.ans) && k.cur.paid) {
      final r = score(k.cur.ans);
      if (big) return (tr('{0}가 본 {1} · {2}', [cg(k.who), k.label(i), k.cur.date]), null);
      return ('${r.code} · ${C.nick[r.code]!}', kAccentInk);
    }
    final r = kidResult(k);
    if (r != null) return ('${r.code} · ${C.nick[r.code]!}', kAccentInk);
    if (k.cur.paid) return (tr('검사 중 · {0}/{1}', [answered(k.cur.ans), C.items.length]), null);
    return (tr('아직 검사 전 · 66문항 무료'), null);
  }

  /// 성장 발달 한 줄(홈 카드용 짧은 글): 체크 중 / 판정 요약 + 키 / 아직
  String devLine(Kid k) {
    final last = k.devLast, open = k.devOpen;
    if (open != null && open.band == devBand(devMonths(k.birth, k.age).$1 ?? -1)) return tr('체크 중 · {0}/{1}', [open.ans.length, open.items.length]);
    if (last == null) return tr('아직 체크 전 · 6개 영역 + 키·몸무게');
    final r = devScore(last), good = r.count('fast') + r.count('ok');
    return [tr('6개 중 {0}개 또래만큼', [good]), if (last.h != null) '${last.h}cm'].join(' · ');
  }

  /// 오늘 한 줄: 다가오는 약속이 있으면 약속, 아니면 오늘의 미션
  String todayLine(Kid k) {
    final up = daily.plansOf(k).where((p) => !p.done && !p.date.isBefore(today0)).toList();
    final rec = daily.peek(k, missionDay);
    final mission = rec?.done == true ? tr('오늘 미션 완료') : tr('미션: {0}', [daily.mission(k, missionDay).$2.t]);
    if (up.isEmpty) return mission;
    final p = up.first, dd = p.date.difference(today0).inDays;
    final when = dd == 0 ? tr('오늘') : dd == 1 ? tr('내일') : tr('{0}일 뒤', [dd]);
    return tr('{0} {1} · {2}', [when, p.tm, p.t]).replaceAll('  ', ' ');
  }

  /// 아이 카드: 그림 · 이름 · 나이와 성별 + 기질·성격 / 성장 발달 / 오늘 세 줄. big 이면 그림을 크게(아이가 한 명일 때)
  Widget kidCard(BuildContext context, Kid k, int i, {bool big = false}) {
    // 큰 카드인데 자리가 좁으면(작은 화면에 아이 카드 줄까지 있을 때) 그림을 이름 옆으로 옮기고 유형은 그 아래 한 줄로
    if (big) return LayoutBuilder(builder: (_, c) => kidCardBody(context, k, i, big: true, roomy: c.maxHeight >= 330));
    return kidCardBody(context, k, i);
  }

  Widget kidCardBody(BuildContext context, Kid k, int i, {bool big = false, bool roomy = true}) {
    final r = kidResult(k);
    final img = Image.asset(r != null ? 'assets/img/t_${r.code}.webp' : 'assets/img/mascot_child.webp', fit: BoxFit.contain);
    final (tv, tc) = tempLine(k, i, big: big);
    final info = [if (k.ageText.isNotEmpty) ageTx(k.ageText) else tr('나이 미입력'), if (k.sex == 'M') tr('남자아이'), if (k.sex == 'F') tr('여자아이')].join(' · ');
    final side = !big || !roomy;
    final head = Row(children: [
      if (side) ...[SizedBox(width: big ? 64 : 50, height: big ? 64 : 50, child: img), const SizedBox(width: 10)],
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(k.label(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(22)),
        Text(info, maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted),
      ])),
      linkBtn(tr('바꾸기'), () {
        store.setKid(k.id);
        editKid(context);
      }),
    ]);
    final lines = [
      line(Key('home-temp-$i'), 'i_doc', tr('기질·성격'), tv, () => go(k.id, 1), color: tc),
      line(Key('home-dev-$i'), 'i_check', tr('성장 발달'), devLine(k), () => go(k.id, 4)),
      line(Key('home-today-$i'), 'i_chat', tr('오늘'), todayLine(k), () => go(k.id, 3)),
    ];
    return NineBox(nCard,
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
        child: Column(mainAxisSize: big ? MainAxisSize.max : MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          if (big) ...[
            if (roomy) Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: img)) else const Spacer(),
            if (r != null) Center(child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [codeText([for (final x in r.ax) (x.letter, x.a.color)], size: roomy ? 34 : 28), const SizedBox(width: 10), Text(C.nick[r.code]!, style: disp(roomy ? 22 : 19))]))),
            if (roomy) const SizedBox(height: 6) else const Spacer(),
          ] else
            const SizedBox(height: 8),
          for (var j = 0; j < lines.length; j++) ...[if (j > 0) const SizedBox(height: 5), lines[j]],
        ]));
  }

  /// 아이 고르기 한 칸: 작은 그림 + 이름. 고른 아이로 앱 전체(기질·성격 · 성장 발달 · 오늘)가 진행된다.
  Widget kidPick(Kid k, int i, bool on) {
    final r = kidResult(k);
    return GestureDetector(
      key: Key('home-kid-$i'),
      onTap: () => store.setKid(k.id),
      child: NineBox(on ? nChipOn : nChip,
          padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(r != null ? 'assets/img/t_${r.code}.webp' : 'assets/img/mascot_child.webp', width: 30, height: 30),
            const SizedBox(width: 6),
            Text(k.label(i), style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kOnAccent : kFg)),
          ])),
    );
  }

  /// 아이가 여럿일 때 고르지 않은 아이의 작은 카드: 그림 · 이름 · 유형(또는 검사 전). 누르면 그 아이가 큰 카드로
  Widget miniCard(Kid k, int i, double w) {
    final r = kidResult(k);
    return GestureDetector(
      key: Key('home-kid-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => store.setKid(k.id),
      child: SizedBox(
          width: w,
          child: NineBox(nCard,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(r != null ? 'assets/img/t_${r.code}.webp' : 'assets/img/mascot_child.webp', width: 52, height: 52),
                const SizedBox(height: 2),
                Text(k.label(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(18)),
                Text(r != null ? r.code : tr('검사 전'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: r != null ? kAccentInk : kMuted)),
              ]))),
    );
  }

  /// 아이 추가 작은 카드(아이가 여럿일 때 작은 카드 줄 끝)
  Widget addCard(BuildContext context, double w) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => newKid(context),
        child: SizedBox(
            width: w,
            child: NineBox(nSoft,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 52, child: Center(child: Text('+', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: kMuted)))),
                  const SizedBox(height: 2),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(tr('+ 아이 추가'), maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kFg))),
                  const SizedBox(height: 16),
                ]))),
      );

  @override
  Widget build(BuildContext context) {
    final ks = store.kids, kid = store.kid;
    final fresh = ks.length <= 1 && kid.name.isEmpty && !kid.cgs.any((e) => e.value.hasAny);
    if (fresh) return welcome(context);
    final idx = ks.indexWhere((k) => k.id == kid.id), cur = idx < 0 ? 0 : idx;
    final done = fullDone(kid.cur.ans) && kid.cur.paid;
    final many = ks.length > 1;
    final sub = many ? tr('아이 카드를 누르면 그 아이로 앱이 진행돼요') : tr('{0}의 오늘을 한눈에', [store.nm]);
    return Frame(
      top: header(sub),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 아이가 한 명: 위에 아이 고르기 칩 + 아이 추가
        if (!many) ...[
          chipRow([kidPick(kid, cur, true), ChipBtn(tr('+ 아이 추가'), onTap: () => newKid(context))]),
          const SizedBox(height: 8),
        ],
        // 고른 아이는 큰 카드
        Expanded(child: KeyedSubtree(key: many ? Key('home-kid-$cur') : null, child: kidCard(context, kid, cur, big: true))),
        // 아이가 여럿: 나머지 아이도 모두 작은 카드로 한눈에(한 줄에 3칸, 넘치면 옆으로 밀어 보기)
        if (many) ...[
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 16) / 3;
            return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < ks.length; i++)
                    if (i != cur) ...[miniCard(ks[i], i, w), const SizedBox(width: 8)],
                  addCard(context, w),
                ]));
          }),
        ],
        const SizedBox(height: 8),
        Row(children: [
          quick('i_heart', tr('가족 초대'), () => inviteCg(context)),
          const SizedBox(width: 6),
          if (done) quick('i_share', tr('결과 공유'), () => openShare(context, tr('결과 공유'))) else quick('i_doc', tr('샘플 리포트'), () => showSample(context)),
        ]),
      ]),
    );
  }

  /// 처음 연 사람: 무엇을 하게 되는지 세 걸음과 시작 버튼
  Widget welcome(BuildContext context) => Frame(
        top: header(tr('만 2~7세 · 부모가 답하는 기질·성격 검사')),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: NineBox(nCard,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Image.asset('assets/img/mascot_child.webp', fit: BoxFit.contain))),
                  FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(style: disp(27), children: [TextSpan(text: tr('우리 아이 ')), TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk)), TextSpan(text: tr(', 알아볼까요?'))]))),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [Tag(tr('무료')), Tag(tr('66문항')), Tag(tr('약 10분'))]),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    stepCell(1, tr('아이 등록'), tr('이름 · 생년월 · 성별')),
                    stepCell(2, tr('66문항 답하기'), tr('평소 모습 그대로')),
                    stepCell(3, tr('리포트 받기'), tr('기질 · 성격 · 또래 평균')),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: Btn(tr('시작하기'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen())), kind: BtnKind.dark)),
                ])),
          ),
          const SizedBox(height: 8),
          Tile(tr('샘플 리포트 먼저 보기'), icon: 'i_doc', sub: tr('예시 아이 콩이의 리포트'), onTap: () => showSample(context)),
          const SizedBox(height: 6),
          Tile(tr('가족에게 초대받았어요'), icon: 'i_send', sub: tr('초대 코드를 넣고 같은 아이로 이어서 검사'), onTap: () => enterCode(context)),
        ]),
      );
}
