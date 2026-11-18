// 함께: 가족 초대·결과 보내기·결과 카드 공유·앱 추천·받은 링크 열기. 한 화면에 할 일 줄, 보내기는 아래 창에서.
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'land.dart';
import 'links.dart';

class ShareView extends StatelessWidget {
  const ShareView({super.key});

  // 카카오톡 · 다른 앱 · 링크 복사를 한 줄로
  Widget buttons(BuildContext context, String kind, {String Function()? role}) => Row(children: [
        Expanded(flex: 13, child: KakaoBtn(() => doKakao(context, kind, role: role?.call() ?? ''), label: '카카오톡')),
        const SizedBox(width: 8),
        Expanded(flex: 10, child: Btn('다른 앱', () => doShare(context, kind, role: role?.call() ?? ''), kind: BtnKind.ghost, dense: true)),
        const SizedBox(width: 8),
        Expanded(
            flex: 11,
            child: Btn('링크 복사', () async {
              await Clipboard.setData(ClipboardData(text: shareMsg(kind, role: role?.call() ?? '').$3));
              if (context.mounted) {
                Navigator.of(context).pop();
                toast(context, '링크를 복사했습니다. 카카오톡이나 문자에 붙여 넣어 보내 주세요.');
              }
            }, kind: BtnKind.ghost, dense: true)),
      ]);

  @override
  Widget build(BuildContext context) {
    final kid = store.kid, cur = store.cur, nm = store.nm;
    final r = fullDone(cur.ans) && cur.paid ? score(cur.ans) : null;
    final roles = kCgl.where((n) => n != kid.who).toList();
    final from = '${kid.inv?['from'] ?? '가족'}';
    return Frame(
      top: tabTitle('함께 보기'),
      body: Fit(col([
        const Text('함께 보면 아이가 더 잘 보여요.', style: smallMuted),
        if (kid.inv != null && r != null)
          Tile('$from에게 결과 보내기', icon: 'i_send', sub: "$from의 휴대폰 '양육자 비교'에 합쳐집니다",
              onTap: () => sheet(context, title: '$from에게 결과 보내기', (c, set) => [
                    muted('결과 링크에는 아이 이름·연령과 답이 실립니다.'),
                    buttons(c, 'back'),
                  ])),
        Tile('공동 양육자 초대', icon: 'i_heart', sub: '다른 휴대폰에서 $nm 검사하고 비교하기', onTap: () {
          var role = roles.first;
          sheet(context, title: '다른 휴대폰에서 $nm 검사하게 초대', (c, set) => [
                muted('누구를 초대하나요?'),
                chips([for (final n in roles) ChipBtn(n, on: role == n, onTap: () => set(() => role = n))]),
                buttons(c, 'invite', role: () => role),
                muted(
                    "링크를 열면 $nm의 검사로 바로 들어갑니다. ${kid.firstDone ? '첫 검사가 이미 결제되어 ${Price.fmt(Price.more)}로 시작합니다.' : '아직 첫 검사 전이라 받은 사람이 먼저 하면 첫 검사 ${Price.fmt(Price.first)}입니다.'} 다 마치면 결과를 다시 보내 '양육자 비교'에 합칩니다. 링크에는 아이 이름·연령이 실리니 믿을 수 있는 가족에게만 보내 주세요."),
              ]);
        }),
        Tile(r != null ? '결과 카드 공유 · ${r.code}' : '결과 카드 공유', icon: 'i_share', sub: r != null ? '이름과 답은 빼고 유형과 별명만 보냅니다' : '정밀검사를 마치면 보낼 수 있어요',
            onTap: r == null
                ? null
                : () => sheet(context, (c, set) => [
                      Row(children: [
                        mascot(r.code, size: 92),
                        const SizedBox(width: 12),
                        Expanded(child: col([codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 38), h3(C.nick[r.code]!)], gap: 2, x: CrossAxisAlignment.start)),
                      ]),
                      muted('아이 이름과 답은 빼고 유형과 별명만 보냅니다.'),
                      buttons(c, 'result'),
                    ])),
        Tile('친구에게 앱 추천', icon: 'i_star', sub: '우리 아이는 어떤 네 글자일까요?', onTap: () => sheet(context, title: '친구에게 앱 추천하기', (c, set) => [buttons(c, 'app')])),
        Tile('받은 링크 열기', icon: 'i_doc', sub: '카카오톡으로 받은 초대·결과 링크', onTap: () {
          final ctl = TextEditingController();
          sheet(context, title: '받은 초대·결과 링크 열기', (c, set) => [
                PaperField(ctl, hint: '받은 링크 붙여 넣기', maxLength: 4000),
                Btn('열기', () {
                  final l = Landing.parse(ctl.text);
                  if (l == null) {
                    toast(c, '열 수 있는 링크가 아닙니다.');
                    return;
                  }
                  Navigator.of(c).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => LandScreen(l)));
                }),
              ]);
        }),
      ], gap: 10)),
    );
  }
}
