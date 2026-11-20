// 한 문항씩 답하기: 한 화면에 문항과 선택지가 모두 보인다. 고르면 짧은 선택 연출(약 0.4초) 뒤 다음 문항.
// 다시 검사할 때는 선택지 옆에 지난번 내 답과 다른 양육자의 답을 보여 준다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../stats.dart';
import '../store.dart';
import 'kit.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with SingleTickerProviderStateMixin {
  late final List<Item> list;
  int i = 0;

  /// 고른 답 연출: 고른 칸이 살짝 커졌다 돌아오고 체크가 뜨며, 나머지는 흐려진다. 끝나면 다음 문항.
  late final _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  int? _picked;

  @override
  void initState() {
    super.initState();
    final left = C.items.where((x) => store.cur.ans[x.id] == null).toList();
    list = left.isEmpty ? List.of(C.items) : left;
  }

  bool get re => store.cur.prev?.ans != null;

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  Future<void> pick(int a) async {
    if (_fx.isAnimating) return;
    store.answer(list[i], a);
    setState(() => _picked = a);
    await _fx.forward(from: 0);
    if (!mounted) return;
    _picked = null;
    _fx.value = 0;
    next();
  }

  void next() {
    if (i < list.length - 1) {
      setState(() => i++);
    } else {
      tab.value = 1;
      Navigator.of(context).pop();
      stats.submitPending();
    }
  }

  void help() => popup(context, title: '답하기 애매할 때', (c, set) => [
        Text("'보통이다'는 그럴 때도 있고 아닐 때도 있다는 뜻입니다. 예시와 꼭 같지 않아도 비슷한 모습이면 됩니다.", style: small),
        Text("떠오르는 장면이 없으면 '잘 모르겠다'를 골라 주세요. 그 문항은 점수에 넣지 않고 비슷한 다른 문항으로 판단합니다.", style: small),
        if (re) Text('다시 검사 중에는 선택지 옆에 지난번 나(${store.cur.prev!.date})와 다른 양육자가 고른 답이 보입니다. 지난 답에 맞추지 말고 요즘 모습대로 골라 주세요.', style: small),
        Btn('확인', () => Navigator.of(c).pop(), kind: BtnKind.ghost),
      ]);

  @override
  Widget build(BuildContext context) {
    final it = list[i], n = list.length, cur = store.cur, kid = store.kid;
    final others = re ? kid.cgs.where((e) => e.key != kid.who && e.value.ans[it.id] != null).toList() : <MapEntry<String, Rec>>[];
    List<String> marks(int k) => [
          if (re && cur.prev!.ans![it.id] == k) '지난번 나',
          for (final o in others) if (o.value.ans[it.id] == k) o.key,
        ];
    Widget opt(int k, String label) {
      final sel = cur.ans[it.id] == k, unk = k == 0, m = marks(k), hit = _picked == k;
      final box = GestureDetector(
        onTap: () => pick(k),
        child: NineBox(sel ? nOptSel : unk ? nOptUnk : nOpt,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/dot_ring.webp'), fit: BoxFit.fill)),
                child: Center(child: Text(unk ? '?' : '$k', style: disp(15))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: unk ? kMuted : kFg))),
              for (final x in m) Padding(padding: const EdgeInsets.only(left: 4), child: Tag(x)),
              if (hit)
                FadeTransition(
                  opacity: CurvedAnimation(parent: _fx, curve: const Interval(0, .4)),
                  child: Padding(padding: const EdgeInsets.only(left: 6), child: Image.asset('assets/ui/i_check.webp', width: 22, height: 22)),
                ),
            ])),
      );
      if (_picked == null) return box;
      // 고른 칸: 1 → 1.05 → 1 로 톡 튀기, 나머지 칸: 흐리게
      return AnimatedBuilder(
        animation: _fx,
        builder: (_, child) => hit
            ? Transform.scale(scale: 1 + .05 * math.sin(math.pi * math.min(1, _fx.value / .6)), child: child)
            : Opacity(opacity: 1 - .55 * math.min(1, _fx.value / .3), child: child),
        child: box,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Frame(
          top: Row(children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).pop(),
              child: SizedBox(width: 40, height: 44, child: Center(child: Image.asset('assets/ui/i_close.webp', width: 22, height: 22))),
            ),
            Expanded(child: ProgressBar(i / n)),
            SizedBox(width: 64, child: Text('${i + 1} / $n', textAlign: TextAlign.right, style: smallMuted)),
          ]),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Fit(
                key: ValueKey(it.id),
                align: Alignment.center,
                col([
                  muted('${re ? '다시 검사 · ' : ''}최근 한 달간 ${store.nm}의 모습 · ${kid.who} 답함'),
                  Text(it.t, style: disp(25, w: FontWeight.w700)),
                  Note(rich('**예** ${it.ex}', style: small)),
                ], gap: 12)),
          ),
          foot: [
            for (var k = 1; k <= 5; k++) opt(k, C.opt[k - 1]),
            opt(0, '잘 모르겠다'),
            Row(children: [
              linkBtn('← 이전 문항', i == 0 || _picked != null ? () {} : () => setState(() => i--)),
              const Spacer(),
              linkBtn('답하기 애매할 때', help),
            ]),
          ],
        ),
      ),
    );
  }
}
