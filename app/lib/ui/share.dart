// 공유: 초대받은 사람의 결과 보내기, 결과 카드, 공동 양육자 초대, 앱 추천, 받은 링크 열기
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../main.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'land.dart';
import 'links.dart';

class ShareView extends StatefulWidget {
  const ShareView({super.key});
  @override
  State<ShareView> createState() => _ShareViewState();
}

class _ShareViewState extends State<ShareView> {
  String role = '';
  final linkCtl = TextEditingController();

  // 카카오톡 · 다른 앱 · 링크 복사를 한 줄로
  Widget buttons(String kind, {String role = ''}) => Row(children: [
        Expanded(flex: 13, child: KakaoBtn(() => doShare(context, kind, role: role), label: '카카오톡')),
        const SizedBox(width: 8),
        Expanded(flex: 10, child: Btn('다른 앱', () => doShare(context, kind, role: role), kind: BtnKind.ghost, dense: true)),
        const SizedBox(width: 8),
        Expanded(
            flex: 11,
            child: Btn('링크 복사', () async {
              await Clipboard.setData(ClipboardData(text: shareMsg(kind, role: role).$3));
              if (mounted) toast(context, '링크를 복사했습니다. 카카오톡이나 문자에 붙여 넣어 보내 주세요.');
            }, kind: BtnKind.ghost, dense: true)),
      ]);

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur, nm = store.nm;
    final r = fullDone(cur.ans) && cur.paid ? score(cur.ans) : null;
    final roles = kCgl.where((n) => n != kid.who).toList();
    if (!roles.contains(role)) role = roles.first;
    final from = '${kid.inv?['from'] ?? '가족'}';
    return AppPage([
      col([eyebrow('공유하기'), h1('함께 보면 더 잘 보여요')], gap: 6),
      if (kid.inv != null && r != null)
        PaperCard([
          h2('$from에게 결과 보내기'),
          muted("보내면 $from의 휴대폰에서 '양육자 비교'에 합쳐집니다."),
          buttons('back'),
        ]),
      PaperCard([
        eyebrow('공동 양육자에게'),
        h2('다른 휴대폰에서 $nm 검사하게 초대'),
        chipRow([for (final n in roles) ChipBtn(n, on: role == n, onTap: () => setState(() => role = n))]),
        buttons('invite', role: role),
        Fold(
            '초대하면 어떻게 되나요?',
            muted(
                "초대받은 사람은 링크를 열면 $nm의 검사로 바로 들어갑니다. ${kid.firstDone ? '첫 검사가 이미 결제되어 ${Price.fmt(Price.more)}로 시작합니다.' : '아직 $nm의 첫 검사 전이라 받은 사람이 먼저 하면 첫 검사 ${Price.fmt(Price.first)}입니다.'} 다 마치면 결과를 다시 보내 이 휴대폰의 '양육자 비교'에 합칩니다. 초대·결과 링크에는 아이 이름·연령(결과 링크는 답도)이 실리니 믿을 수 있는 가족에게만 보내 주세요.")),
      ]),
      PaperCard([
        eyebrow('친구·가족에게'),
        if (r != null) ...[
          Row(children: [
            mascot(r.code, size: 84),
            const SizedBox(width: 12),
            Expanded(child: col([codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 36), h3(C.nick[r.code]!)], gap: 2, x: CrossAxisAlignment.start)),
          ]),
          muted('아이 이름과 답은 빼고 유형과 별명만 보냅니다.'),
          buttons('result'),
        ] else ...[
          h2('우리 아이 MBTI 알려 주기'),
          muted('정밀검사를 마치면 유형 카드를 공유할 수 있어요.'),
        ],
      ]),
      PaperCard([
        eyebrow('앱 알리기'),
        h2('친구에게 앱 추천하기'),
        buttons('app'),
      ]),
      PaperCard([
        Fold(
            '받은 초대·결과 링크 열기',
            col([
        muted('카카오톡으로 받은 초대 링크나 결과 링크를 붙여 넣으면 이 앱에서 엽니다.'),
        PaperField(linkCtl, hint: '받은 링크 붙여 넣기', maxLength: 4000),
        Btn('열기', () {
          final l = Landing.parse(linkCtl.text);
          if (l == null) {
            toast(context, '열 수 있는 링크가 아닙니다.');
            return;
          }
          linkCtl.clear();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LandScreen(l)));
        }, kind: BtnKind.ghost),
            ], gap: 10)),
      ]),
      muted('시제품: 카카오 앱 키를 넣기 전이라 카카오톡으로 보내기는 휴대폰 공유 창(카카오톡 선택 가능)으로 보냅니다.'),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: openPrivacy, child: const Text('개인정보처리방침'))),
    ]);
  }
}
