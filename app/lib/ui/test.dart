// 한 문항씩 답하기. 다시 검사할 때는 선택지 옆에 지난번 내 답과 다른 양육자의 답을 보여 준다.
import 'package:material_ui/material_ui.dart';
import '../content.dart';
import '../main.dart';
import '../store.dart';
import 'kit.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late final List<Item> list;
  int i = 0;

  @override
  void initState() {
    super.initState();
    final left = C.items.where((x) => store.cur.ans[x.id] == null).toList();
    list = left.isEmpty ? List.of(C.items) : left;
  }

  bool get re => store.cur.prev?.ans != null;

  void pick(int a) {
    store.answer(list[i], a);
    if (i < list.length - 1) {
      setState(() => i++);
    } else {
      tab.value = 1;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = list[i], n = list.length, cur = store.cur, kid = store.kid;
    final others = re ? kid.cgs.where((e) => e.key != kid.who && e.value.ans[it.id] != null).toList() : <MapEntry<String, Rec>>[];
    List<String> marks(int k) => [
          if (re && cur.prev!.ans![it.id] == k) '지난번 나',
          for (final o in others) if (o.value.ans[it.id] == k) o.key,
        ];
    Widget opt(int k, String label, {String? sub}) {
      final sel = cur.ans[it.id] == k, unk = k == 0, m = marks(k);
      return GestureDetector(
        onTap: () => pick(k),
        child: NineBox(sel ? nOptSel : unk ? nOptUnk : nOpt,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/dot_ring.webp'), fit: BoxFit.fill)),
                child: Center(child: Text(unk ? '?' : '$k', style: disp(16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: col([
                Text(label, style: TextStyle(fontSize: 16, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: kFg)),
                if (sub != null) Text(sub, style: smallMuted),
              ], gap: 0)),
              if (m.isNotEmpty) Wrap(spacing: 4, children: [for (final x in m) Tag(x)]),
            ])),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: col([
                col([
                  Row(children: [
                    Expanded(child: Text(re ? '다시 검사하기 · ${kid.who}' : '내 아이의 MBTI 정밀검사 · ${kid.who}', style: smallMuted)),
                    Text('${i + 1} / $n', style: smallMuted),
                  ]),
                  SizedBox(
                    height: 14,
                    child: LayoutBuilder(
                        builder: (c, bc) => Stack(children: [
                              Positioned.fill(child: NineBox(nTrack, padding: EdgeInsets.zero, child: const SizedBox.expand())),
                              Positioned(left: 2, top: 2, bottom: 2, width: (bc.maxWidth - 4) * i / n, child: Image.asset('assets/ui/bar_sky.webp', fit: BoxFit.fill)),
                            ])),
                  ),
                ], gap: 6),
                if (re)
                  Note(rich("**다시 검사 중입니다.** 선택지 옆에 **지난번 나**(${cur.prev!.date})${kid.cgs.length > 1 ? '와 다른 양육자' : ''}가 고른 답이 보입니다. 지난 답에 맞추지 말고 요즘 모습대로 골라 주세요.", style: small)),
                muted('최근 한 달간 ${store.nm}의 모습에 가장 가까운 것을 골라 주세요.'),
                Text(it.t, style: disp(23, w: FontWeight.w700)),
                Note(rich('**예** ${it.ex}', style: small)),
                for (var k = 1; k <= 5; k++) opt(k, C.opt[k - 1]),
                opt(0, '잘 모르겠다', sub: '본 적이 없거나 판단하기 애매해요'),
                Fold(
                    '답하기 애매할 때',
                    muted("'보통이다'는 그럴 때도 있고 아닐 때도 있다는 뜻입니다. 예시와 꼭 같지 않아도 비슷한 모습이면 됩니다. 떠오르는 장면이 없으면 '잘 모르겠다'를 골라 주세요. 그 문항은 점수에 넣지 않고 비슷한 다른 문항으로 판단합니다.")),
                Row(children: [
                  Expanded(child: Btn('이전 문항', i == 0 ? null : () => setState(() => i--), kind: BtnKind.ghost)),
                  const SizedBox(width: 10),
                  Expanded(child: Btn('나중에 하기', () => Navigator.of(context).pop(), kind: BtnKind.ghost)),
                ]),
              ], gap: 16),
            ),
          ),
        ]),
      ),
    );
  }
}
