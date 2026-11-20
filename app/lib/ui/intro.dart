// 앱을 켤 때: 원더휠 스플래시 → 타이틀 화면(화면을 터치하면 시작) → 홈
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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

  /// 원더휠 CI 영상(WONDERWHEEL_CI_FINAL_V33 밝은 판 세로, 흰 바탕, 5초, 소리 없음).
  /// 영상을 못 열면(테스트·3초 안에 시작 못 함) 로고 그림을 1.8초 보여 준다.
  VideoPlayerController? _c;
  bool _videoOn = false, _fallback = false;
  final _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(seconds: 3), _toLogo);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final s = MediaQuery.sizeOf(context);
    // 휴대폰 세로(9:16)와 태블릿 세로(3:4) 중 화면 비율에 가까운 쪽
    final tablet = s.height > 0 && s.width / s.height > .66;
    final c = VideoPlayerController.asset(tablet ? 'assets/video/wonderwheel_tablet.mp4' : 'assets/video/wonderwheel_portrait.mp4');
    _c = c;
    try {
      await c.initialize();
      await c.setVolume(0);
      if (!mounted || phase != 0 || _fallback) return;
      c.addListener(_tick);
      _t?.cancel();
      setState(() => _videoOn = true);
      await c.play();
    } catch (e) {
      debugPrint('intro video: $e');
      _toLogo();
    }
  }

  void _tick() {
    final v = _c?.value;
    if (v == null) return;
    if (v.hasError || v.isCompleted) toTitle();
  }

  /// 영상 대신 로고 그림을 잠깐 보여 주고 타이틀로
  void _toLogo() {
    if (!mounted || phase != 0 || _videoOn || _fallback) return;
    _t?.cancel();
    setState(() => _fallback = true);
    _t = Timer(const Duration(milliseconds: 1800), toTitle);
  }

  void _skip() {
    if (_clock.elapsedMilliseconds >= 500) toTitle();
  }

  void toTitle() {
    _t?.cancel();
    if (!mounted || phase == 1) return;
    setState(() => phase = 1);
    _blink.repeat(reverse: true);
    _c?.removeListener(_tick);
    _c?.pause();
  }

  @override
  void dispose() {
    _t?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: phase == 0 ? Colors.white : kBg,
        body: GestureDetector(
          key: const Key('intro'),
          behavior: HitTestBehavior.opaque,
          onTap: () => phase == 0 ? _skip() : introDone.value = true,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: phase == 0 ? splash() : title()),
        ),
      );

  /// 원더휠 스플래시: CI 영상. 영상을 쓸 수 없으면 흰 바탕 가운데 회사 로고(관람차 + WONDERWHEEL)
  Widget splash() {
    final c = _c;
    if (_videoOn && c != null && c.value.isInitialized) {
      return SizedBox.expand(
        key: const ValueKey('splash'),
        child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
      );
    }
    if (!_fallback) return const SizedBox.expand(key: ValueKey('splash'));
    return logo();
  }

  Widget logo() => SizedBox.expand(
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
        child: Stack(children: [
          Positioned.fill(child: titleBody()),
          // 화면 한가운데에서 깜빡이는 안내 (터치는 화면 전체가 받는다)
          Center(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _blink, curve: Curves.easeInOut),
                child: NineBox(nChip, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), child: Text('화면을 터치하면 시작해요', style: disp(24, color: kAccentInk))),
              ),
            ),
          ),
        ]),
      );

  Widget titleBody() => Frame(
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
            Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('전문기관 수준의 정밀 리포트 · 66문항 · 약 10분 · 광고 보고 무료', maxLines: 1, style: smallMuted))),
            const SizedBox(height: 18),
          ]),
        );
}
