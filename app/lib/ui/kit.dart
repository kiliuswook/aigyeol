// 손그림(색연필) UI 조각. 웹 CSS 의 border-image(9조각 늘이기)를 같은 비율로 그린다.
import 'dart:ui' as ui;
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
Future<void> preloadUi() async {
  const names = ['card', 'box_soft', 'box_dark', 'box_pink', 'btn_blue', 'btn_dark', 'btn_ghost', 'tag', 'input', 'opt', 'opt_sel', 'opt_unk', 'track'];
  for (final n in names) {
    final data = await rootBundle.load('assets/ui/$n.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    _imgs[n] = (await codec.getNextFrame()).image;
  }
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
  const Btn(this.label, this.onTap, {super.key, this.kind = BtnKind.blue, this.icon});
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: kind == BtnKind.ghost ? FontWeight.w500 : FontWeight.w700, color: fg))),
              ])),
        ),
      ),
    );
  }
}

/// 카카오톡 노란 버튼(손그림 대신 카카오 색)
class KakaoBtn extends StatelessWidget {
  final VoidCallback onTap;
  const KakaoBtn(this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFEE500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF191600), width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const SizedBox(height: 52, child: Center(child: Text('카카오톡으로 보내기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF191600))))),
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
        Text(label, style: const TextStyle(fontSize: 13, color: kFg, fontWeight: FontWeight.w500)),
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
  const Fold(this.title, this.child, {super.key});
  @override
  State<Fold> createState() => _FoldState();
}

class _FoldState extends State<Fold> {
  bool open = false;
  @override
  Widget build(BuildContext context) => col([
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
