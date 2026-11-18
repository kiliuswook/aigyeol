// 함께 보기: 가족 초대·결과 보내기·결과 카드 공유·앱 추천. 더보기 탭 위쪽에 칸으로 놓이고, 보내기는 팝업에서.
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'links.dart';

/// 함께 보기 칸 하나
typedef ShareItem = ({String title, String icon, VoidCallback? onTap});

class ShareActions {
  const ShareActions();

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

  List<ShareItem> items(BuildContext context) {
    final kid = store.kid, cur = store.cur, nm = store.nm;
    final r = fullDone(cur.ans) && cur.paid ? score(cur.ans) : null;
    final roles = kCgl.where((n) => n != kid.who).toList();
    final from = '${kid.inv?['from'] ?? '가족'}';
    return [
        if (kid.inv != null && r != null)
          (title: '결과 보내기', icon: 'i_send',
              onTap: () => popup(context, title: '결과 보내기', (c, set) => [
                    muted("$from의 휴대폰 '양육자 비교'에 합쳐집니다. 결과 링크에는 아이 이름·연령과 답이 실립니다."),
                    buttons(c, 'back'),
                  ])),
        (title: '양육자 초대', icon: 'i_heart', onTap: () {
          var role = roles.first;
          popup(context, title: '다른 휴대폰에서 $nm 검사하게 초대', (c, set) => [
                muted('누구를 초대하나요?'),
                chips([for (final n in roles) ChipBtn(n, on: role == n, onTap: () => set(() => role = n))]),
                buttons(c, 'invite', role: () => role),
                muted(
                    "링크를 열면 $nm의 검사로 바로 들어갑니다. ${kid.firstDone ? '첫 검사가 이미 결제되어 ${Price.fmt(Price.more)}로 시작합니다.' : '아직 첫 검사 전이라 받은 사람이 먼저 하면 첫 검사 ${Price.fmt(Price.first)}입니다.'} 다 마치면 결과를 다시 보내 '양육자 비교'에 합칩니다. 링크에는 아이 이름·연령이 실리니 믿을 수 있는 가족에게만 보내 주세요."),
              ]);
        }),
        (title: '결과 공유', icon: 'i_share',
            onTap: r == null
                ? null
                : () => popup(context, title: '결과 공유', (c, set) => [
                      Row(children: [
                        mascot(r.code, size: 92),
                        const SizedBox(width: 12),
                        Expanded(child: col([codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 38), h3(C.nick[r.code]!)], gap: 2, x: CrossAxisAlignment.start)),
                      ]),
                      muted('아이 이름과 답은 빼고 유형과 별명만 보냅니다.'),
                      buttons(c, 'result'),
                    ])),
        (title: '앱 추천', icon: 'i_star', onTap: () => popup(context, title: '친구에게 앱 추천하기', (c, set) => [buttons(c, 'app')])),
    ];
  }
}
