// 손그림(색연필) UI 조각. 웹 CSS 의 border-image(9조각 늘이기)를 같은 비율로 그린다.
import '../i18n.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../content.dart';

const kBg = Color(0xFFFBF5EA), kSurface = Color(0xFFFFFDF8), kSunk = Color(0xFFF5EDE0), kLine = Color(0xFFE2D4BF);
const kFg = Color(0xFF36405A), kMuted = Color(0xFF656C80), kAccent = Color(0xFF8CC4EA), kAccentInk = Color(0xFF2D6C98), kOnAccent = Color(0xFF1F2E45);
const kDisplay = 'Gaegu';

/// 9조각 이미지: 원본 slice 픽셀을 화면 width 논리 픽셀로 그린다(CSS: url() slice fill / width)
class Nine {
  final String name;
  final double slice, width;
  const Nine(this.name, this.slice, this.width);
}

const nCard = Nine('card', 22, 15), nSoft = Nine('box_soft', 27, 12), nDark = Nine('box_dark', 30, 15), nPink = Nine('box_pink', 25, 14);
const nBtn = Nine('btn_blue', 60, 24), nBtnDark = Nine('btn_dark', 60, 24), nBtnGhost = Nine('btn_ghost', 61, 24);
const nTag = Nine('tag', 33, 13), nChip = Nine('tag', 33, 18), nChipOn = Nine('btn_blue', 60, 18), nInput = Nine('input', 23, 11);
const nOpt = Nine('opt', 30, 13), nOptSel = Nine('opt_sel', 32, 13), nOptUnk = Nine('opt_unk', 31, 13), nTrack = Nine('track', 25, 7);

final Map<String, ui.Image> _imgs = {};

/// 9조각 테두리 그림을 한꺼번에(동시에) 풀어 둔다. 앱을 켤 때 기다리는 시간이라 하나씩 풀지 않는다.
Future<void> preloadUi() async {
  const names = ['card', 'box_soft', 'box_dark', 'box_pink', 'btn_blue', 'btn_dark', 'btn_ghost', 'tag', 'input', 'opt', 'opt_sel', 'opt_unk', 'track'];
  await Future.wait([
    for (final n in names)
      () async {
        final data = await rootBundle.load('assets/ui/$n.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _imgs[n] = (await codec.getNextFrame()).image;
      }(),
  ]);
}

bool _warmed = false;

/// 앱에서 쓰는 작은 그림(아이콘·마스코트·유형 그림·막대)을 미리 풀어 둔다.
/// 처음 보는 화면에서 그림이 한 박자 늦게 뜨거나 화면이 덜컥이는 것을 막는다. 앱을 켤 때 한 번.
Future<void> warmImages(BuildContext context) async {
  if (_warmed) return;
  _warmed = true;
  try {
    final all = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    final names = [
      for (final a in all)
        if ((a.startsWith('assets/ui/') || a.startsWith('assets/img/mascot') || a.startsWith('assets/img/t_')) && a.endsWith('.webp')) a,
    ];
    // 인트로가 먼저 닫혀도 이어서 풀 수 있게 설정을 미리 받아 둔다
    if (!context.mounted) return;
    final cfg = createLocalImageConfiguration(context);
    // 한 번에 몰아서 풀면 그 순간 화면이 버벅일 수 있어 몇 개씩 나눈다
    for (var i = 0; i < names.length; i += 6) {
      await Future.wait([for (final n in names.skip(i).take(6)) _warm(AssetImage(n), cfg)]);
    }
  } catch (_) {}
}

/// precacheImage 와 같지만 BuildContext 없이: 그림을 풀어 이미지 캐시에 남긴다
Future<void> _warm(ImageProvider p, ImageConfiguration cfg) {
  final done = Completer<void>();
  final stream = p.resolve(cfg);
  late final ImageStreamListener l;
  l = ImageStreamListener((_, _) {
    if (!done.isCompleted) done.complete();
    // 캐시에 남도록 다음 프레임에 듣기를 멈춘다(precacheImage 와 같은 방식)
    SchedulerBinding.instance.addPostFrameCallback((_) => stream.removeListener(l));
  }, onError: (_, _) {
    if (!done.isCompleted) done.complete();
    stream.removeListener(l);
  });
  stream.addListener(l);
  return done.future;
}

class _NinePainter extends CustomPainter {
  final Nine n;
  _NinePainter(this.n);
  @override
  void paint(Canvas c, Size size) {
    final img = _imgs[n.name];
    if (img == null) return;
    final s = n.width / n.slice;
    final sl = n.slice;
    final center = Rect.fromLTRB(sl, sl, img.width - sl, img.height - sl);
    c.save();
    c.scale(s);
    c.drawImageNine(img, center, Rect.fromLTWH(0, 0, size.width / s, size.height / s), Paint()..filterQuality = FilterQuality.medium);
    c.restore();
  }

  @override
  bool shouldRepaint(_NinePainter o) => o.n != n;
}

class NineBox extends StatelessWidget {
  final Nine n;
  final Widget child;
  final EdgeInsets padding;
  const NineBox(this.n, {super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NinePainter(n), child: Padding(padding: padding, child: child));
}

// ---------- 글자 ----------
TextStyle disp(double size, {Color? color, FontWeight w = FontWeight.w700}) => TextStyle(fontFamily: kDisplay, fontSize: size, fontWeight: w, color: color ?? kFg, height: 1.3);
const small = TextStyle(fontSize: 13, height: 1.55, color: kFg);
const smallMuted = TextStyle(fontSize: 13, height: 1.55, color: kMuted);
const body = TextStyle(fontSize: 15, height: 1.65, color: kFg);

Widget eyebrow(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kAccentInk, letterSpacing: .4));
Widget h1(String t, {Color? color}) => Text(t, style: disp(28, color: color));
Widget h2(String t, {Color? color}) => Text(t, style: disp(23, color: color));
Widget h3(String t) => Text(t, style: disp(19));
Widget p(String t, {TextStyle style = body, TextAlign? align}) => Text(t, style: style, textAlign: align);
Widget muted(String t) => Text(t, style: smallMuted);

/// **굵게** 표시를 지원하는 문단
Widget rich(String t, {TextStyle style = body}) {
  final parts = t.split('**');
  return Text.rich(TextSpan(style: style, children: [
    for (var i = 0; i < parts.length; i++) TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null)
  ]));
}

// ---------- 묶음 ----------
Widget col(List<Widget> c, {double gap = 12, CrossAxisAlignment x = CrossAxisAlignment.stretch}) =>
    Column(crossAxisAlignment: x, mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: gap), c[i]]]);

class PaperCard extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const PaperCard(this.children, {super.key, this.gap = 12});
  @override
  Widget build(BuildContext context) => NineBox(nCard, padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), child: col(children, gap: gap));
}

class Note extends StatelessWidget {
  final Widget child;
  const Note(this.child, {super.key});
  @override
  Widget build(BuildContext context) => NineBox(nSoft, padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: DefaultTextStyle.merge(style: small, child: child));
}

class Cta extends StatelessWidget {
  final List<Widget> children;
  const Cta(this.children, {super.key});
  @override
  Widget build(BuildContext context) => NineBox(nDark,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: DefaultTextStyle.merge(style: const TextStyle(color: kBg), child: col(children)));
}

// ---------- 버튼 ----------
enum BtnKind { blue, dark, ghost }

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final Widget? icon;
  /// 좁은 칸에 여럿 놓을 때: 옆 여백과 글자를 줄여 한 줄에
  final bool dense;
  const Btn(this.label, this.onTap, {super.key, this.kind = BtnKind.blue, this.icon, this.dense = false});
  @override
  Widget build(BuildContext context) {
    final n = switch (kind) { BtnKind.blue => nBtn, BtnKind.dark => nBtnDark, BtnKind.ghost => nBtnGhost };
    final fg = switch (kind) { BtnKind.blue => kOnAccent, BtnKind.dark => kBg, BtnKind.ghost => kFg };
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: NineBox(n,
              padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 18, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: dense ? 1 : null, softWrap: !dense, style: TextStyle(fontSize: dense ? 14 : 16, fontWeight: kind == BtnKind.ghost ? FontWeight.w500 : FontWeight.w700, color: fg))),
              ])),
        ),
      ),
    );
  }
}

/// 카카오톡 노란 버튼(손그림 대신 카카오 색)
class KakaoBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const KakaoBtn(this.onTap, {super.key, this.label = '카카오톡으로 보내기'});
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFEE500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF191600), width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(height: 52, child: Center(child: Text(tr(label), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF191600))))),
        ),
      );
}

class ChipBtn extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;
  const ChipBtn(this.label, {super.key, this.on = false, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: NineBox(on ? nChipOn : nChip,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? kOnAccent : kFg))),
        ),
      );
}

Widget chips(List<Widget> c) => Wrap(spacing: 8, runSpacing: 8, children: c);

/// 칩 한 줄: 넘치면 옆으로 밀어 보기(세로 길이를 늘리지 않음)
Widget chipRow(List<Widget> c) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 8), c[i]]]));

class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});
  @override
  Widget build(BuildContext context) =>
      NineBox(nTag, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4), child: Text(label, style: const TextStyle(fontSize: 13, color: kFg)));
}

/// 색 점이 붙은 판정 꼬리표
class Pill extends StatelessWidget {
  final String label;
  final String c; // c1~c4, g
  const Pill(this.label, this.c, {super.key});
  @override
  Widget build(BuildContext context) => NineBox(nTag,
      padding: const EdgeInsets.fromLTRB(10, 4, 13, 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/ui/dot_$c.webp', width: 12, height: 12),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: kFg, fontWeight: FontWeight.w500))),
      ]));
}

// ---------- 막대 ----------
/// 0~100 점수 막대. 가운데 40~60 균형 띠, 50에서 점까지 채움(fill), 이전 점수(was)는 빈 동그라미.
class Track extends StatelessWidget {
  final int? score, was;
  final String c;
  final bool thin, fill;
  const Track(this.score, this.c, {super.key, this.thin = false, this.fill = false, this.was});
  @override
  Widget build(BuildContext context) {
    final h = thin ? 10.0 : 16.0, dot = thin ? 16.0 : 22.0;
    return SizedBox(
      height: dot,
      child: LayoutBuilder(builder: (ctx, bc) {
        final w = bc.maxWidth;
        double x(int s) => w * s / 100;
        return Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
          Positioned(left: 0, right: 0, top: (dot - h) / 2, height: h, child: NineBox(nTrack, padding: EdgeInsets.zero, child: const SizedBox.expand())),
          Positioned(left: x(40), width: x(20), top: (dot - h) / 2 + 2, height: h - 4, child: Container(color: const Color(0x33B9A88F))),
          if (fill && score != null)
            Positioned(
                left: c == 'g' ? 0 : x(score! < 50 ? score! : 50), width: c == 'g' ? x(score!) : x((score! - 50).abs()),
                top: (dot - h) / 2 + 1, height: h - 2,
                child: Opacity(opacity: c == 'g' ? 1 : .55, child: Image.asset('assets/ui/bar_$c.webp', fit: BoxFit.fill))),
          if (was != null) Positioned(left: x(was!) - dot / 2, top: 0, child: Image.asset('assets/ui/dot_ring.webp', width: dot, height: dot)),
          if (score != null) Positioned(left: x(score!) - dot / 2, top: 0, child: Image.asset('assets/ui/dot_$c.webp', width: dot, height: dot)),
        ]);
      }),
    );
  }
}

/// 축 막대: 왼쪽 낮은 쪽 이름, 막대, 오른쪽 높은 쪽 이름
Widget axisBar(Ax a, int s, {bool thin = false}) => Row(children: [
      SizedBox(width: 44, child: Text(a.lo, style: TextStyle(fontSize: 13, fontWeight: s < 50 ? FontWeight.w700 : FontWeight.w400, color: s < 50 ? kFg : kMuted))),
      Expanded(child: Track(s, a.c, thin: thin, fill: true)),
      SizedBox(width: 44, child: Text(a.hi, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: s >= 50 ? FontWeight.w700 : FontWeight.w400, color: s >= 50 ? kFg : kMuted))),
    ]);

Widget codeText(List<(String, Color)> letters, {double size = 54}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (final l in letters) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(l.$1, style: disp(size, color: l.$2)))]);

Widget mascot(String code, {double size = 112}) => Image.asset('assets/img/t_$code.webp', width: size, height: size, fit: BoxFit.contain);

/// 펼쳐 보기(웹 details)
class Fold extends StatefulWidget {
  final String title;
  final Widget child;
  /// 접힌 상태에서도 보이는 머리(막대 같은 핵심). 있으면 제목 대신 이것을 누른다
  final Widget? head;
  final bool open;
  const Fold(this.title, this.child, {super.key, this.head, this.open = false});
  @override
  State<Fold> createState() => _FoldState();
}

class _FoldState extends State<Fold> {
  late bool open = widget.open;
  @override
  Widget build(BuildContext context) => col([
        if (widget.head != null)
          InkWell(
            onTap: () => setState(() => open = !open),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: widget.head),
          )
        else
        InkWell(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Image.asset(open ? 'assets/ui/i_tri_down.webp' : 'assets/ui/i_tri.webp', width: 16, height: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, color: kAccentInk))),
            ]),
          ),
        ),
        if (open) widget.child,
      ], gap: 8);
}

/// 손그림 입력칸
class PaperField extends StatelessWidget {
  final TextEditingController ctl;
  final String hint;
  final ValueChanged<String>? onChanged;
  final int maxLength;
  final bool obscure;
  final TextInputType? keyboard;
  const PaperField(this.ctl, {super.key, this.hint = '', this.onChanged, this.maxLength = 10, this.obscure = false, this.keyboard});
  @override
  Widget build(BuildContext context) => NineBox(nInput,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: ctl,
        onChanged: onChanged,
        maxLength: maxLength,
        obscureText: obscure,
        keyboardType: keyboard,
        autocorrect: !obscure && keyboard == null,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, counterText: '', isDense: false),
      ));
}

void toast(BuildContext ctx, String t) => ScaffoldMessenger.of(ctx)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(t), backgroundColor: kFg, behavior: SnackBarBehavior.floating));

// ---------- 앱 화면 틀(스크롤 없이 한 화면) ----------
/// 한 화면에 맞추는 칸. 내용이 칸보다 길 때만(작은 폰·큰 글씨) 그 칸 안에서 밀린다.
class Fit extends StatelessWidget {
  final Widget child;
  final Alignment align;
  const Fit(this.child, {super.key, this.align = Alignment.topCenter});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (c, bc) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: bc.maxHeight, minWidth: bc.maxWidth, maxWidth: bc.maxWidth), child: Align(alignment: align, child: child))));
}

/// 화면 하나: 위 줄(top) · 남는 높이를 채우는 가운데(body) · 아래에 붙는 버튼(foot). 최대 폭 480.
class Frame extends StatelessWidget {
  final Widget? top;
  final Widget body;
  final List<Widget> foot;
  const Frame({super.key, this.top, required this.body, this.foot = const []});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (top != null) ...[top!, const SizedBox(height: 10)],
              Expanded(child: body),
              for (final f in foot) ...[const SizedBox(height: 8), f],
            ]),
          ),
        ),
      );
}

/// 밀어 넣은 화면의 위 줄: 왼쪽 뒤로/닫기, 가운데 제목, 오른쪽 덧붙임
class TopBar extends StatelessWidget {
  final String title;
  final bool close;
  final Widget? right;
  final VoidCallback? onBack;
  const TopBar(this.title, {super.key, this.close = false, this.right, this.onBack});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: SizedBox(width: 44, height: 44, child: Center(child: Image.asset(close ? 'assets/ui/i_close.webp' : 'assets/ui/i_arrow_l.webp', width: 22, height: 22))),
          ),
          Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: disp(20))),
          SizedBox(width: 44, child: right ?? const SizedBox()),
        ]),
      );
}

/// 탭 화면의 위 줄: 큰 제목
Widget tabTitle(String t, {Widget? right}) => SizedBox(height: 44, child: Row(children: [Expanded(child: Text(t, style: disp(26))), if (right != null) right]));

/// 줄 메뉴 한 칸: 그림 · 제목 · 설명 · 화살표
class Tile extends StatelessWidget {
  final String? icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;
  const Tile(this.title, {super.key, this.icon, this.sub, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: NineBox(nCard,
              padding: const EdgeInsets.fromLTRB(16, 11, 14, 12),
              child: Row(children: [
                if (icon != null) ...[Image.asset('assets/ui/$icon.webp', width: 28, height: 28), const SizedBox(width: 12)],
                Expanded(
                    child: col([
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kFg, height: 1.3)),
                  if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMuted, height: 1.35)),
                ], gap: 1)),
                const SizedBox(width: 8),
                Image.asset('assets/ui/i_tri.webp', width: 14, height: 14),
              ])),
        ),
      );
}

/// 쪽 표시 점
class Dots extends StatelessWidget {
  final int n, i;
  const Dots(this.n, this.i, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < n; k++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: k == i ? 18 : 7, height: 7,
            decoration: BoxDecoration(color: k == i ? kAccentInk : kLine, borderRadius: BorderRadius.circular(9)),
          ),
      ]);
}

/// 글줄 버튼(가벼운 보조 행동)
Widget linkBtn(String t, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kAccentInk))));

/// 진행 막대(0~1)
class ProgressBar extends StatelessWidget {
  final double v;
  const ProgressBar(this.v, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: LayoutBuilder(
            builder: (c, bc) => Stack(children: [
                  Positioned.fill(child: NineBox(nTrack, padding: EdgeInsets.zero, child: const SizedBox.expand())),
                  Positioned(left: 2, top: 2, bottom: 2, width: (bc.maxWidth - 4) * v.clamp(0, 1), child: Image.asset('assets/ui/bar_sky.webp', fit: BoxFit.fill)),
                ])),
      );
}

/// '자세히 보기': 눈에 띄는 파란 버튼. 화면에 나타날 때 세 번 통통 튀어 눌러 볼 곳임을 알린다.
class MoreBtn extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const MoreBtn(this.onTap, {super.key, this.label = '자세히 보기'});
  @override
  State<MoreBtn> createState() => _MoreBtnState();
}

class _MoreBtnState extends State<MoreBtn> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  int n = 0;

  @override
  void initState() {
    super.initState();
    c.addStatusListener((st) {
      if (st == AnimationStatus.completed) c.reverse();
      if (st == AnimationStatus.dismissed && ++n < 3) c.forward();
    });
    c.forward();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: c,
          builder: (ctx, child) => Transform.scale(scale: 1 + .07 * Curves.easeInOut.transform(c.value), child: child),
          child: Container(
            margin: const EdgeInsets.fromLTRB(4, 2, 5, 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x552D6C98), blurRadius: 8, offset: Offset(0, 3))]),
            child: NineBox(nChipOn,
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr(widget.label), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOnAccent)),
                  const SizedBox(width: 4),
                  Image.asset('assets/ui/i_arrow_r.webp', width: 16, height: 16),
                ])),
          ),
        ),
      );
}

/// 가운데 뜨는 팝업창. 설명·읽는 법, 고르기·보내기·입력까지 한 단계 더 들어가는 것은 모두 여기에 띄운다.
/// 아래에서 올라오는 창(bottom sheet)은 쓰지 않는다(2026-11-19 원더).
Future<T?> popup<T>(BuildContext ctx, List<Widget> Function(BuildContext c, StateSetter set) build, {String? title, String? icon}) => showDialog<T>(
      context: ctx,
      barrierColor: const Color(0x8836405A),
      builder: (c) => StatefulBuilder(
          builder: (c, set) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: NineBox(nCard,
                      padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          if (icon != null) ...[Image.asset('assets/ui/$icon.webp', width: 28, height: 28), const SizedBox(width: 8)],
                          Expanded(child: Text(title ?? '', style: disp(23))),
                          InkWell(
                            key: const Key('popup-close'),
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.of(c).pop(),
                            child: SizedBox(width: 44, height: 44, child: Center(child: Image.asset('assets/ui/i_close.webp', width: 22, height: 22))),
                          ),
                        ]),
                        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.only(right: 6, top: 4), child: col(build(c, set), gap: 10))),
                      ])),
                ),
              )),
    );
