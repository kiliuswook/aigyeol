// 아이 등록: 한 화면에 하나씩 묻는다(이름·연령 → 답하는 사람 → 결제). 아이 정보 바꾸기는 아래에서 올라오는 창.
import 'package:flutter/material.dart';
import '../store.dart';
import 'flow.dart';
import 'kit.dart';

const kAges = ['만 2세', '만 3세', '만 4세', '만 5세', '만 6세', '만 7세'];

Widget ageChips(VoidCallback changed) => chips([
      for (final a in kAges)
        ChipBtn(a, on: store.kid.age == a, onTap: () {
          store.setInfo(age: store.kid.age == a ? '' : a);
          changed();
        }),
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
        Center(child: Image.asset('assets/img/mascot_child.webp', width: 96, height: 96)),
        h1('어떤 아이인가요?'),
        muted('이름은 이 휴대폰에만 저장됩니다. 별명이어도 좋아요.'),
        PaperField(name, hint: '아이 이름 또는 별명 (예: 콩이)', onChanged: (v) => store.setInfo(name: v)),
        const SizedBox(height: 2),
        muted('연령 (만 2~7세)'),
        ageChips(() => setState(() {})),
      ]),
      col([
        Center(child: Image.asset('assets/img/mascot_parent.webp', width: 96, height: 96)),
        h1('누가 답하나요?'),
        muted('${store.nm}를 가장 가까이에서 보는 사람이 답해 주세요. 다른 양육자는 나중에 따로 검사하고 비교할 수 있어요.'),
        chips([for (final n in kCgl) ChipBtn(n, on: kid.who == n, onTap: () => setState(() => store.setWho(n)))]),
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
            top: TopBar('아이 등록', onBack: back, right: Center(child: Text('${step + 1}/2', style: smallMuted))),
            body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Fit(key: ValueKey(step), pages[step])),
            foot: [
              Dots(2, step),
              Btn(step == 0 ? '다음' : '검사 준비 끝', () {
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
  return sheet(context, title: '아이 정보', (c, set) => [
        PaperField(name, hint: '아이 이름 또는 별명', onChanged: (v) => store.setInfo(name: v)),
        muted('연령'),
        ageChips(() => set(() {})),
        Btn('완료', () => Navigator.of(c).pop()),
      ]);
}

/// 답하는 사람 추가: 이 휴대폰에서 답할 사람을 고르거나, 다른 휴대폰으로 초대한다
Future<void> addWho(BuildContext context, {required VoidCallback invite}) {
  final has = store.kid.cgs.map((e) => e.key).toSet();
  return sheet(context, title: '답하는 사람 추가', (c, set) => [
        muted('이 휴대폰에서 이어서 답할 사람을 골라 주세요. 추가 검사는 ${Price.fmt(Price.more)}입니다.'),
        chips([
          for (final n in kCgl.where((n) => !has.contains(n)))
            ChipBtn(n, onTap: () {
              store.setWho(n);
              Navigator.of(c).pop();
            }),
        ]),
        Btn('다른 휴대폰으로 초대하기', () {
          Navigator.of(c).pop();
          invite();
        }, kind: BtnKind.ghost),
      ]);
}
