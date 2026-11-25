// 아이 등록: 한 화면에 하나씩 묻는다(이름·태어난 해와 달 → 답하는 사람 → 광고 보고 검사). 아이 정보 바꾸기는 아래에서 올라오는 창.
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../stats.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';

/// 태어난 해와 달 고르기. 만 나이는 앱이 계산해서 아래에 보여 준다(만 나이를 헷갈리지 않게).
Widget birthPicker(VoidCallback changed) {
  final kid = store.kid, p = kid.birth.split('-'), now = DateTime.now();
  final y = p.length == 2 ? p[0] : '', m = p.length == 2 ? '${int.tryParse(p[1]) ?? ''}' : '';
  void set(String yy, String mm) {
    // 해와 달을 모두 골라야 나이를 센다. 하나만 고른 동안은 'YYYY-' / '-M' 로 잠시 둔다
    store.setInfo(birth: yy.isEmpty && mm.isEmpty ? '' : '$yy-${mm.isEmpty ? '' : mm.padLeft(2, '0')}');
    changed();
  }

  // 고르기 칸: 손그림 입력칸 + 손그림 ▼. 누르면 가운데 팝업에 손그림 선택지 격자가 뜬다(기본 드롭다운 메뉴는 톤이 안 맞아서 쓰지 않음)
  Widget drop(String hint, String value, List<(String, String)> items, ValueChanged<String> on, {int cols = 2}) => Builder(builder: (ctx) {
        final label = [for (final (v, t) in items) if (v == value) t].firstOrNull;
        return Semantics(
          button: true,
          label: label ?? hint,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final v = await popup<String>(
                  ctx,
                  (c, _) => [
                        GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: cols == 2 ? 2.6 : 1.9,
                          children: [
                            for (final (v, t) in items)
                              GestureDetector(
                                onTap: () => Navigator.of(c).pop(v),
                                child: NineBox(v == value ? nOptSel : nOpt,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Center(
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(t, style: disp(20, color: v == value ? kOnAccent : kFg))))),
                              ),
                          ],
                        ),
                      ],
                  title: hint);
              if (v != null) on(v);
            },
            child: NineBox(nInput,
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: [
                  Expanded(
                      child: Text(label ?? hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label == null ? body.copyWith(color: kMuted) : disp(20))),
                  Image.asset('assets/ui/i_tri_down.webp', width: 18, height: 18),
                ])),
          ),
        );
      });
  final age = ageOf(kid.birth).$2, yrs = int.tryParse(RegExp(r'\d+').firstMatch(ageOf(kid.birth).$1)?.group(0) ?? '');
  return col([
    Row(children: [
      Expanded(flex: 6, child: drop(tr('태어난 해'), y, [for (var k = now.year; k >= now.year - 9; k--) ('$k', tr('{0}년', [k]))], (v) => set(v, m))),
      const SizedBox(width: 10),
      Expanded(flex: 5, child: drop(tr('태어난 달'), m, [for (var k = 1; k <= 12; k++) ('$k', tr('{0}월', [k]))], (v) => set(y, v), cols: 3)),
    ]),
    if (age.isNotEmpty)
      Row(children: [
        Tag(tr('지금 {0}', [ageTx(age)])),
        const SizedBox(width: 8),
        if (yrs != null && (yrs < 2 || yrs > 7)) Expanded(child: Text(tr('이 검사는 만 2~7세에 맞춰져 있어요.'), style: smallMuted)),
      ])
    else if (kid.age.isNotEmpty)
      muted(tr('전에 고른 연령: {0}. 태어난 해와 달을 넣으면 나이가 자동으로 맞춰져요.', [ageTx(kid.age)])),
  ], gap: 8);
}

/// 성별 고르기(같은 나이·성별 아이들의 평균과 비교하는 데 쓴다)
Widget sexPicker(VoidCallback changed) => Row(children: [
      for (final (v, t) in [('M', tr('남자아이')), ('F', tr('여자아이'))]) ...[
        if (v == 'F') const SizedBox(width: 8),
        Expanded(
            child: GestureDetector(
                onTap: () {
                  store.setInfo(sex: v);
                  changed();
                },
                child: NineBox(store.kid.sex == v ? nChipOn : nChip,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Center(child: Text(t, style: disp(19, color: store.kid.sex == v ? kOnAccent : kMuted)))))),
      ],
    ]);

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupState();
}

class _SetupState extends State<SetupScreen> {
  late final String kidId = store.kid.id;
  late final name = TextEditingController(text: store.kid.name);
  int step = 0;
  bool done = false;

  void back() {
    if (step > 0) {
      setState(() => step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // 아무것도 넣지 않고 나간 새 아이는 남기지 않는다
    if (!done) Future.microtask(() => store.dropBlankKid(kidId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kid = store.kid;
    final pages = [
      col([
        Center(child: Image.asset('assets/img/mascot_child.webp', width: 72, height: 72)),
        h1(tr('어떤 아이인가요?')),
        muted(tr('이름은 이 휴대폰에만 저장됩니다. 별명이어도 좋아요.')),
        PaperField(name, hint: tr('아이 이름 또는 별명 (예: 콩이)'), onChanged: (v) => store.setInfo(name: v)),
        const SizedBox(height: 2),
        muted(tr('태어난 해와 달 (만 나이는 자동으로 계산해요)')),
        birthPicker(() => setState(() {})),
        sexPicker(() => setState(() {})),
      ], gap: 8),
      col([
        Center(child: Image.asset('assets/img/mascot_parent.webp', width: 96, height: 96)),
        h1(tr('누가 답하나요?')),
        muted(tr('{0}를 가장 가까이에서 보는 사람이 답해 주세요. 다른 양육자는 나중에 따로 검사하고 비교할 수 있어요.', [store.nm])),
        chips([
          for (final n in kCgl.where((n) => n != kOtherCg)) ChipBtn(cg(n), on: kid.who == n, onTap: () => setState(() => store.setWho(n))),
          // '기타 양육자' 는 이름을 직접 적는다 (예: 이모, 삼촌, 선생님). 적은 이름이 칩에 보인다.
          ChipBtn(cg(kCgl.contains(kid.who) ? kOtherCg : kid.who), on: !kCgl.contains(kid.who) || kid.who == kOtherCg, onTap: () async {
            final n = await askCgName(context, initial: kCgl.contains(kid.who) ? '' : kid.who);
            if (n != null) setState(() => store.setWho(n));
          }),
        ]),
      ]),
    ];
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Frame(
            top: TopBar(tr('아이 등록'), onBack: back, right: Center(child: Text('${step + 1}/2', style: smallMuted))),
            body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Fit(key: ValueKey(step), pages[step])),
            foot: [
              Dots(2, step),
              Btn(step == 0 ? tr('다음') : tr('검사 준비 끝'), () {
                if (step == 0) {
                  FocusScope.of(context).unfocus();
                  setState(() => step = 1);
                } else {
                  done = true;
                  Navigator.of(context).pop();
                  startFull(context);
                }
              }, kind: BtnKind.dark),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아이 이름·연령 바꾸기
Future<void> editKid(BuildContext context) {
  final name = TextEditingController(text: store.kid.name);
  return popup(context, title: tr('아이 정보'), (c, set) => [
        PaperField(name, hint: tr('아이 이름 또는 별명'), onChanged: (v) => store.setInfo(name: v)),
        muted(tr('태어난 해와 달')),
        birthPicker(() => set(() {})),
        sexPicker(() => set(() {})),
        Btn(tr('완료'), () {
          Navigator.of(c).pop();
          stats.submitPending();
        }),
      ]);
}

/// 답하는 사람 추가: 이 휴대폰에서 답할 사람을 고르거나, 다른 휴대폰으로 초대한다
Future<void> addWho(BuildContext context, {required VoidCallback invite}) {
  final has = store.kid.cgs.map((e) => e.key).toSet();
  return popup(context, title: tr('답하는 사람 추가'), (c, set) => [
        muted(tr('이 휴대폰에서 이어서 답할 사람을 골라 주세요. 광고 1번 보면 무료로 검사합니다.')),
        chips([
          for (final n in kCgl.where((n) => !has.contains(n) && n != kOtherCg))
            ChipBtn(cg(n), onTap: () {
              store.setWho(n);
              Navigator.of(c).pop();
            }),
          ChipBtn(tr('{0} (이름 적기)', [cg(kOtherCg)]), onTap: () async {
            final n = await askCgName(c, taken: has);
            if (n == null) return;
            store.setWho(n);
            if (c.mounted) Navigator.of(c).pop();
          }),
        ]),
        Btn(tr('다른 휴대폰으로 초대하기'), () {
          Navigator.of(c).pop();
          invite();
        }, kind: BtnKind.ghost),
      ]);
}

/// '기타 양육자' 이름 적기 (예: 이모, 삼촌, 선생님). 비우거나 닫으면 null.
/// [taken] 에 이미 있는 이름이면 다시 적게 한다.
Future<String?> askCgName(BuildContext context, {String initial = '', Set<String> taken = const {}}) {
  final ctl = TextEditingController(text: initial);
  String? err;
  return popup<String>(context, title: tr('누가 답하나요?'), (c, set) => [
        muted(tr('아이와의 관계나 부르는 이름을 적어 주세요. 비교 화면에 이 이름으로 보여요.')),
        PaperField(ctl, hint: tr('예: 이모, 삼촌, 선생님'), maxLength: 8),
        if (err != null) Text(err!, style: smallMuted),
        Btn(tr('확인'), () {
          final n = ctl.text.trim();
          if (n.isEmpty) return set(() => err = tr('이름을 적어 주세요.'));
          if (taken.contains(n)) return set(() => err = tr('이미 있는 이름이에요. 다른 이름을 적어 주세요.'));
          Navigator.of(c).pop(n);
        }, kind: BtnKind.dark),
      ]);
}
