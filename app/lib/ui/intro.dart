// 앱을 켤 때: 원더휠 스플래시 → 타이틀 화면(화면을 터치하면 시작) → 홈
import 'dart:async';
import 'package:flutter/material.dart';
import '../store.dart';
import 'kit.dart';

/// 인트로를 지났는지. 앱을 켤 때마다 한 번 보여 준다.
final introDone = ValueNotifier<bool>(false);

class Intro extends StatefulWidget {
  const Intro({super.key});
  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  /// 0 스플래시, 1 타이틀
  int phase = 0;
  Timer? _t;
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 1800), toTitle);
  }

  void toTitle() {
    _t?.cancel();
    if (!mounted || phase == 1) return;
    setState(() => phase = 1);
    _blink.repeat(reverse: true);
  }

  @override
  void dispose() {
    _t?.cancel();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: phase == 0 ? Colors.white : kBg,
        body: GestureDetector(
          key: const Key('intro'),
          behavior: HitTestBehavior.opaque,
          onTap: () => phase == 0 ? toTitle() : introDone.value = true,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: phase == 0 ? splash() : title()),
        ),
      );

  /// 원더휠 스플래시: 흰 바탕 가운데 회사 로고(관람차 + WONDERWHEEL)
  Widget splash() => SizedBox.expand(
        key: const ValueKey('splash'),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Center(child: FractionallySizedBox(widthFactor: .56, child: Image.asset('assets/img/wonderwheel.png', errorBuilder: (_, _, _) => const Text('WonderWheel', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kFg))))),
        ),
      );

  /// 타이틀 화면: 그림과 앱 소개. 버튼 없이 화면을 터치하면 시작한다.
  Widget title() => SafeArea(
        key: const ValueKey('title'),
        child: Frame(
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
            const SizedBox(height: 16),
            Center(child: eyebrow('만 2~7세 · 부모가 답하는 기질검사')),
            const SizedBox(height: 2),
            Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(style: disp(44), children: const [TextSpan(text: '내 아이의 '), TextSpan(text: 'MBTI', style: TextStyle(color: kAccentInk))])))),
            Center(child: Text('우리 아이의 MBTI는 무엇일까요?', style: disp(21, w: FontWeight.w400))),
            const SizedBox(height: 8),
            for (final (t, d) in const [('기질검사', '타고난 성향 4축과 세부 기질 12가지'), ('성격검사', '경험으로 자라는 끈기 · 스스로 힘 · 함께 힘')])
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/ui/i_check.webp', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Flexible(child: rich('**$t** $d', style: small)),
                ]),
              ),
            const SizedBox(height: 6),
            Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('전문기관 수준의 정밀 리포트 · 66문항 · 약 10분 · 첫 검사 ${Price.fmt(Price.first)}', maxLines: 1, style: smallMuted))),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: Tween(begin: .25, end: 1.0).animate(_blink),
              child: Center(child: Text('화면을 터치하면 시작해요', style: disp(22, color: kAccentInk))),
            ),
            const SizedBox(height: 18),
          ]),
        ),
      );
}
