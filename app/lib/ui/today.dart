// 오늘 탭: 부모 칭찬 스티커 미션 · 아이와의 약속·일정 · 상황 카드. 한 화면, 위 칩으로 세 칸을 오간다.
// 문장은 assets/data/daily.json(미리 쓴 글, AI 호출 없음). 기록은 daily.dart.
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../daily.dart';
import '../main.dart';
import '../notify.dart';
import '../store.dart';
import 'kit.dart';

/// 오늘 탭 안의 칸: 0 미션, 1 약속·일정, 2 상황 카드
final todaySeg = ValueNotifier<int>(0);

final _segs = [tr('오늘의 미션'), tr('약속·일정'), tr('상황 카드')];
final _reacts = [tr('잘 통했어요'), tr('그냥 그랬어요'), tr('안 통했어요')];
final _wd = [tr('월'), tr('화'), tr('수'), tr('목'), tr('금'), tr('토'), tr('일')];

String _md(DateTime d) => tr('{0}월 {1}일({2})', [d.month, d.day, _wd[d.weekday - 1]]);

/// 고를 스티커 6개: 우리 아이 유형 그림 + 날마다 바뀌는 다른 유형 그림
List<String> _stickers(Kid k) {
  final all = C.nick.keys.toList();
  final own = kidResult(k)?.code;
  final n = missionDay.difference(DateTime(2026, 1, 1)).inDays;
  final out = <String>[?own];
  for (var i = 0; out.length < 6 && i < all.length; i++) {
    final c = all[(n * 5 + i * 3) % all.length];
    if (!out.contains(c)) out.add(c);
  }
  return out;
}

Widget _sticker(String code, {double size = 30}) => Image.asset('assets/img/t_$code.webp', width: size, height: size, fit: BoxFit.contain);

/// 부모가 스티커를 고르는 칸(2026-11-20 원더: 아이가 아니라 부모가 고른다)
List<Widget> _pickSticker(BuildContext c, Kid k, void Function(String) onPick) => [
      Text(tr('오늘 받을 스티커를 골라 주세요.'), style: body),
      muted(tr('마음에 드는 스티커를 골라 엄마·아빠 스티커판에 붙여요.')),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (final s in _stickers(k))
          GestureDetector(
            key: Key('sticker-$s'),
            onTap: () => onPick(s),
            child: NineBox(nSoft, padding: const EdgeInsets.all(8), child: _sticker(s, size: 72)),
          ),
      ]),
    ];

class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([daily, todaySeg]),
      builder: (context, _) {
        final ks = store.kids, k = store.kid, seg = todaySeg.value;
        return Frame(
          top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            // 아이는 홈에서 고른다
            tabTitle(tr('오늘'), right: kidTag(store.nm, many: ks.length > 1, onTap: () => tab.value = 0)),
            chipRow([for (var i = 0; i < _segs.length; i++) ChipBtn(_segs[i], on: seg == i, onTap: () => todaySeg.value = i)]),
          ]),
          body: switch (seg) { 0 => _MissionPane(k), 1 => _PlanPane(k), _ => _CardPane(k) },
        );
      });
}

// ---------------- 오늘의 미션 ----------------
class _MissionPane extends StatelessWidget {
  final Kid k;
  const _MissionPane(this.k);

  Future<void> doIt(BuildContext context) {
    var step = 0, react = 0;
    final memo = TextEditingController();
    return popup(context, title: tr('해 봤어요'), icon: 'i_check', (c, set) {
      if (step == 1) {
        return _pickSticker(c, k, (s) {
          daily.complete(k, sticker: s, react: react, memo: memo.text.trim());
          Navigator.of(c).pop();
          toast(context, tr('스티커 1개를 받았어요. 오늘도 해냈어요!'));
        });
      }
      return [
        Text(tr('{0}의 반응은 어땠나요?', [store.nm]), style: body),
        chips([for (var i = 0; i < 3; i++) ChipBtn(_reacts[i], on: react == i, onTap: () => set(() => react = i))]),
        PaperField(memo, hint: tr('한 줄 메모 (선택) 예: 처음엔 웃기만 했어요'), maxLength: 60),
        Btn(tr('다음: 스티커 고르기'), () => set(() => step = 1), kind: BtnKind.dark),
      ];
    });
  }

  Future<void> log(BuildContext context) => popup(context, title: tr('잘 통한 말 기록'), icon: 'i_doc', (c, set) {
        final g = daily.goodLog(k);
        return [
          if (g.isEmpty) muted(tr('"잘 통했어요"를 고르거나 메모를 남긴 날이 여기에 모여요.')),
          for (final (d, t) in g) Text.rich(TextSpan(style: small, children: [TextSpan(text: '${_md(dparse(d))}  ', style: const TextStyle(color: kMuted)), TextSpan(text: t)])),
        ];
      });

  @override
  Widget build(BuildContext context) {
    // 미션은 매일 오전 9시에 바뀐다(9시 전에는 어제 미션)
    final t0 = missionDay;
    final (_, m) = daily.mission(k, t0);
    final rec = daily.peek(k, t0);
    final done = rec?.done ?? false;
    final r = kidResult(k);
    final pole = daily.mission(k, t0).$1.substring(0, 1);
    final mon = t0.subtract(Duration(days: t0.weekday - 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: NineBox(nCard,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Tag(m.k),
                const SizedBox(width: 8),
                Expanded(child: Text(pole == 'X' ? tr('{0}에게', [store.nm]) : tr('{0} {1}에게', [poleName(pole), store.nm]), maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted)),
              ]),
              const SizedBox(height: 6),
              Expanded(
                  child: Fit(
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(m.t, style: disp(25)),
                        const SizedBox(height: 8),
                        Text(m.w, style: smallMuted),
                      ]),
                      align: Alignment.centerLeft)),
              const SizedBox(height: 8),
              if (done)
                Row(children: [
                  _sticker(rec!.st, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('오늘 스티커를 받았어요'), style: disp(20)),
                    if (rec.r >= 0) Text(_reacts[rec.r] + (rec.memo.isNotEmpty ? ' · ${rec.memo}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted),
                  ])),
                  linkBtn(tr('취소'), () => daily.undo(k)),
                ])
              else
                Row(children: [
                  Expanded(flex: 2, child: Btn(tr('다른 미션'), () => daily.swap(k), kind: BtnKind.ghost, dense: true)),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: Btn(tr('해 봤어요'), () => doIt(context), kind: BtnKind.dark, dense: true)),
                ]),
            ])),
      ),
      const SizedBox(height: 8),
      // 이번 주 스티커판
      NineBox(nSoft,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(tr('엄마·아빠 스티커판'), style: disp(19))),
              Flexible(child: Text(tr('연속 {0}일 · 이번 달 {1}개', [daily.streak(k), daily.stickers(k, from: DateTime(t0.year, t0.month))]), maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: () {
                  final d = mon.add(Duration(days: i));
                  final s = daily.peek(k, d);
                  final isToday = d == t0;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_wd[i], style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400, color: isToday ? kAccentInk : kMuted)),
                    SizedBox(
                        width: 36, height: 36,
                        child: s?.done ?? false
                            ? _sticker(s!.st, size: 36)
                            : Padding(padding: const EdgeInsets.all(6), child: Image.asset(isToday ? 'assets/ui/dot_ring_blue.webp' : 'assets/ui/dot_ring.webp', fit: BoxFit.contain))),
                  ]);
                }()),
            ]),
          ])),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text(r == null ? tr('검사를 마치면 {0} 유형에 맞춘 미션이 나와요.', [store.nm]) : tr('{0} {1}에게 맞춘 미션이에요.', [r.code, store.nm]), maxLines: 2, style: smallMuted)),
        linkBtn(tr('잘 통한 말'), () => log(context)),
        if (notify.supported) linkBtn(tr('알림 설정'), () => alarmPopup(context)),
      ]),
    ]);
  }
}

/// 푸시 알림 설정(더보기 > 푸시 알림, 오늘 탭 > 알림 설정): 세 가지를 따로 켜고 끈다
Future<void> alarmPopup(BuildContext context) => popup(context, title: tr('푸시 알림'), icon: 'i_bulb', (c, set) {
      Future<void> toggle(void Function() change) async {
        final was = daily.anyAlarm;
        change();
        set(() {});
        // 처음 켜는 것이면 휴대폰 알림 권한을 묻는다
        if (!was && daily.anyAlarm) {
          final ok = await notify.ask();
          if (!ok && c.mounted) toast(c, tr('휴대폰 설정에서 이 앱의 알림을 허용해 주세요'));
        }
      }

      Widget row(String t, String sub, bool v, void Function(bool) on) => NineBox(nCard,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kFg)),
              Text(sub, style: const TextStyle(fontSize: 12.5, color: kMuted)),
            ])),
            Switch(value: v, activeThumbColor: kAccentInk, onChanged: (x) => toggle(() => on(x))),
          ]));

      return [
        if (!notify.supported) muted(tr('푸시 알림은 앱에서 받을 수 있어요.')),
        row(tr('오늘의 미션'), tr('매일 오전 9시, 새 미션이 나올 때'), daily.alarm, (x) => daily.setAlarm(mission: x)),
        row(tr('저녁 확인'), tr('오후 8:30, 그날 미션을 안 했을 때만'), daily.eve, (x) => daily.setAlarm(evening: x)),
        row(tr('약속·일정'), tr('하루 전, 1시간 전 (시간을 안 정했으면 전날 저녁·당일 아침)'), daily.planAlarm, (x) => daily.setAlarm(plan: x)),
      ];
    });

// ---------------- 약속·일정 ----------------
class _PlanPane extends StatelessWidget {
  final Kid k;
  const _PlanPane(this.k);

  String dday(DateTime d) {
    final n = d.difference(today0).inDays;
    return n == 0 ? tr('오늘') : n == 1 ? tr('내일') : n > 0 ? 'D-$n' : tr('{0}일 전', [-n]);
  }

  Widget row(BuildContext context, Plan p) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => planPopup(context, k, p),
          child: NineBox(nCard,
              padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
              child: Row(children: [
                SizedBox(width: 52, child: Text(dday(p.date), textAlign: TextAlign.center, style: disp(19, color: p.done ? kMuted : kAccentInk))),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.done ? kMuted : kFg, decoration: p.done ? TextDecoration.lineThrough : null)),
                  Text('${p.pr ? tr('약속') : tr('일정')} · ${_md(p.date)}${p.tm.isNotEmpty ? ' ${hm(_min(p.tm))}' : ''}', style: const TextStyle(fontSize: 12.5, color: kMuted)),
                ])),
                if (p.st.isNotEmpty) _sticker(p.st, size: 34) else Image.asset('assets/ui/i_tri.webp', width: 14, height: 14),
              ])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = daily.plansOf(k);
    final up = all.where((p) => !p.done && !p.date.isBefore(today0)).toList();
    final past = all.where((p) => p.done || p.date.isBefore(today0)).toList().reversed.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          child: all.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/img/mascot_child.webp', width: 110, height: 110),
                    const SizedBox(height: 8),
                    Text(tr('{0}와 한 약속을 적어 두세요', [store.nm]), style: disp(22), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(tr('"토요일에 놀이터 가기"처럼요. 날이 다가오면 {0} 성향에 맞춰 미리 알려 주는 방법을 알려 드려요. 약속을 지키면 스티커를 받아요.', [store.nm]), style: smallMuted, textAlign: TextAlign.center),
                  ]))),
                ))
              : ListView(padding: EdgeInsets.zero, children: [
                  if (up.isNotEmpty) ...[eyebrow(tr('다가오는 약속·일정')), const SizedBox(height: 6), for (final p in up) row(context, p)],
                  if (past.isNotEmpty) ...[const SizedBox(height: 4), eyebrow(tr('지난 기록')), const SizedBox(height: 6), for (final p in past) row(context, p)],
                ])),
      const SizedBox(height: 8),
      Btn(tr('+ 약속·일정 적기'), () => addPlan(context, k), kind: BtnKind.dark),
    ]);
  }
}

int _min(String tm) {
  final p = tm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

Future<void> addPlan(BuildContext context, Kid k) {
  var pr = true;
  var date = today0.add(const Duration(days: 1));
  var tm = '';
  final t = TextEditingController();
  return popup(context, title: tr('약속·일정 적기'), icon: 'i_heart', (c, set) {
    Future<void> pickDate() async {
      final d = await showDatePicker(context: c, initialDate: date, firstDate: today0, lastDate: today0.add(const Duration(days: 365)));
      if (d != null) set(() => date = DateTime(d.year, d.month, d.day));
    }

    Future<void> pickTime() async {
      final x = await showTimePicker(context: c, initialTime: const TimeOfDay(hour: 10, minute: 0));
      if (x != null) set(() => tm = '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}');
    }

    final near = [for (var i = 0; i < 3; i++) today0.add(Duration(days: i))];
    return [
      chips([
        ChipBtn(tr('{0}와의 약속', [store.nm]), on: pr, onTap: () => set(() => pr = true)),
        ChipBtn(tr('일정'), on: !pr, onTap: () => set(() => pr = false)),
      ]),
      PaperField(t, hint: pr ? tr('예: 놀이터 가기') : tr('예: 소아과 예방접종'), maxLength: 30),
      chipRow([for (final s in D.plans) ChipBtn(s, onTap: () => set(() => t.text = s))]),
      eyebrow(tr('언제')),
      chipRow([
        for (var i = 0; i < 3; i++) ChipBtn([tr('오늘'), tr('내일'), tr('모레')][i], on: date == near[i], onTap: () => set(() => date = near[i])),
        ChipBtn(near.contains(date) ? tr('다른 날') : _md(date), on: !near.contains(date), onTap: pickDate),
      ]),
      chipRow([
        ChipBtn(tr('시간 없음'), on: tm.isEmpty, onTap: () => set(() => tm = '')),
        ChipBtn(tm.isEmpty ? tr('시간 정하기') : hm(_min(tm)), on: tm.isNotEmpty, onTap: pickTime),
      ]),
      Btn(tr('저장'), () {
        final s = t.text.trim();
        if (s.isEmpty) {
          toast(c, tr('무엇을 하기로 했는지 적어 주세요'));
          return;
        }
        daily.addPlan(Plan(id: rid(), kid: k.id, t: s, d: dkey(date), tm: tm, pr: pr));
        Navigator.of(c).pop();
        toast(context, notify.supported && daily.planAlarm ? tr('저장했어요. 하루 전과 1시간 전에 알려 드려요') : tr('저장했어요'));
      }, kind: BtnKind.dark),
    ];
  });
}

Future<void> planPopup(BuildContext context, Kid k, Plan p) {
  var step = 0;
  return popup(context, title: p.t, icon: p.pr ? 'i_heart' : 'i_doc', (c, set) {
    if (step == 1) {
      return _pickSticker(c, k, (s) {
        daily.finishPlan(p, sticker: s);
        Navigator.of(c).pop();
        toast(context, tr('약속을 지켜서 스티커 1개를 받았어요'));
      });
    }
    final r = kidResult(k);
    final ns = daily.notices(k);
    return [
      Text('${p.pr ? tr('{0}와의 약속', [store.nm]) : tr('일정')} · ${_md(p.date)}${p.tm.isNotEmpty ? ' ${hm(_min(p.tm))}' : ''}', style: smallMuted),
      if (!p.done && !p.date.isBefore(today0)) ...[
        eyebrow(r == null ? tr('미리 알려 주기') : tr('{0} {1}에게 미리 알려 주기', [[for (final l in ns.map((e) => e.$1).toSet()) poleName(l)].join('·'), store.nm])),
        for (final (_, n) in ns)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Text(n.when, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kAccentInk, height: 1.55))),
            Expanded(child: Text(n.t.replaceAll('OO', p.t), style: small)),
          ]),
        if (r == null) muted(tr('검사를 마치면 {0} 성향에 맞춰 알려 드려요.', [store.nm])),
      ],
      if (p.done)
        Row(children: [
          if (p.st.isNotEmpty) ...[_sticker(p.st, size: 44), const SizedBox(width: 10)],
          Expanded(child: Text(p.pr ? tr('약속을 지켰어요') : tr('다녀왔어요'), style: disp(20))),
          linkBtn(tr('다시 열기'), () {
            daily.reopenPlan(p);
            set(() {});
          }),
        ])
      else
        Btn(p.pr ? tr('약속 지켰어요') : tr('다녀왔어요'), () {
          if (p.pr) {
            set(() => step = 1);
          } else {
            daily.finishPlan(p);
            Navigator.of(c).pop();
          }
        }, kind: BtnKind.dark),
      Align(
          alignment: Alignment.centerRight,
          child: linkBtn(tr('지우기'), () {
            daily.removePlan(p);
            Navigator.of(c).pop();
          })),
    ];
  });
}

// ---------------- 상황 카드 ----------------
final _cat = ValueNotifier<String>(tr('전체'));

class _CardPane extends StatelessWidget {
  final Kid k;
  const _CardPane(this.k);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
      valueListenable: _cat,
      builder: (context, cat, _) {
        final cats = [tr('전체'), ...{for (final s in D.situations) s.cat}];
        final list = D.situations.where((s) => cat == tr('전체') || s.cat == cat).toList();
        final r = kidResult(k);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          chipRow([for (final c in cats) ChipBtn(c, on: c == cat, onTap: () => _cat.value = c)]),
          const SizedBox(height: 6),
          Text(r == null ? tr('이런 때 어떻게 말할지, 성향별로 정리했어요.') : tr('{0} {1}에게 맞는 말이 먼저 보여요.', [r.code, store.nm]), style: smallMuted),
          const SizedBox(height: 6),
          Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tile(s.t, sub: '${s.cat} · ${s.p}', onTap: () => sitPopup(context, k, s)),
              ),
          ])),
        ]);
      });
}

Future<void> sitPopup(BuildContext context, Kid k, Situation s) {
  final r = kidResult(k);
  final ax = C.axes.firstWhere((a) => a.id == s.ax);
  final mine = r?.ax.firstWhere((x) => x.a.id == s.ax).letter;
  final order = mine == null ? [ax.h, ax.l] : [mine, mine == ax.h ? ax.l : ax.h];
  Widget block(String l, bool own) {
    final t = s.by[l]!;
    return NineBox(own ? nPink : nSoft,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: col([
          Text(own ? tr('{0} {1}에게', [poleName(l), store.nm]) : mine == null ? tr('{0} 아이라면', [poleName(l)]) : tr('{0} 아이라면 (참고)', [poleName(l)]), style: disp(19)),
          Text.rich(TextSpan(style: small, children: [TextSpan(text: tr('이렇게 말해 보세요  '), style: TextStyle(fontWeight: FontWeight.w700, color: kAccentInk)), TextSpan(text: t.say)])),
          Text.rich(TextSpan(style: small, children: [TextSpan(text: tr('이렇게 해 보세요  '), style: TextStyle(fontWeight: FontWeight.w700, color: kAccentInk)), TextSpan(text: t.act)])),
          Text.rich(TextSpan(style: small, children: [TextSpan(text: tr('이런 말은 피해 주세요  '), style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB4533C))), TextSpan(text: t.no)])),
        ], gap: 6));
  }

  return popup(context, title: s.t, icon: 'i_chat', (c, set) => [
        Text(s.p, style: body),
        for (var i = 0; i < order.length; i++) block(order[i], mine != null && i == 0),
        muted(tr('{0}·{1} 성향에 따라 달라지는 상황이에요. 양육 참고용이며 전문 상담을 대신하지 않습니다.', [ax.hi, ax.lo])),
      ]);
}

/// 홈 등에서 오늘 탭의 한 칸을 바로 연다
void openToday(int seg) {
  todaySeg.value = seg;
  tab.value = 3;
}
