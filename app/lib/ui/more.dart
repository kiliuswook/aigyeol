// 더보기: 함께 보기(초대·공유) + 계정·가격·기록 지우기 + 만든 사람. 한 화면.
import 'package:flutter/material.dart';
import '../main.dart';
import '../store.dart';
import '../sync.dart';
import 'account.dart';
import 'kit.dart';
import 'share.dart';
import 'pay.dart';

class MoreView extends StatelessWidget {
  const MoreView({super.key});

  Future<void> reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${store.nm}의 기록을 지울까요?'),
        content: const Text('이 아이의 검사 답과 결제한 검사가 이 휴대폰에서 모두 지워집니다. 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('지우기', style: TextStyle(color: Color(0xFFC0392B)))),
        ],
      ),
    );
    if (ok == true) {
      store.resetKid();
      tab.value = 0;
    }
  }

  /// 함께 보기 칸: 아이콘 + 이름
  Widget cell(ShareItem it) => Expanded(
      child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: it.onTap,
          child: Opacity(
              opacity: it.onTap == null ? .55 : 1,
              child: NineBox(nCard,
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 11),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/ui/${it.icon}.webp', width: 28, height: 28),
                    const SizedBox(height: 4),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(it.title, maxLines: 1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kFg))),
                  ])))));

  @override
  Widget build(BuildContext context) {
    final sh = const ShareActions().items(context);
    return Frame(
      top: tabTitle('더보기'),
      body: Fit(col([
        eyebrow('함께 보기'),
        Row(children: [
          for (var i = 0; i < sh.length; i++) ...[if (i > 0) const SizedBox(width: 6), cell(sh[i])],
        ]),
        eyebrow('내 정보'),
        ListenableBuilder(
            listenable: sync,
            builder: (context, _) {
              final (t, d) = !sync.signedIn
                  ? ('메일로 로그인·가입', '휴대폰을 바꿔도 기록이 이어져요 (선택)')
                  : !sync.verified
                      ? ('메일 인증이 남았어요', sync.email)
                      : ('내 계정 · 동기화 중', sync.email);
              return Tile(t, icon: 'i_lock', sub: d, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())));
            }),
        Tile('가격 안내', icon: 'i_bulb', sub: '첫 검사 ${Price.fmt(Price.first)} · 추가 검사 ${Price.fmt(Price.more)}', onTap: () => priceSheet(context)),
        Tile('${store.nm}의 기록 지우기', icon: 'i_close', sub: '이 휴대폰에서 이 아이의 기록 초기화', onTap: () => reset(context)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('양육 참고용이며 의학적 진단이 아닙니다. 공개 테스트 중이라 결제 버튼을 누르면 실제 결제 없이 검사가 열립니다.', style: smallMuted),
        ),
      ], gap: 8)),
      // 만든 사람
      foot: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset('assets/img/wonderwheel.webp', width: 26, height: 26, errorBuilder: (_, _, _) => const SizedBox()),
            const SizedBox(width: 8),
            const Text('만든 사람', style: TextStyle(fontSize: 12.5, color: kMuted)),
            const SizedBox(width: 6),
            const Text('원더휠 WonderWheel', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kFg)),
          ]),
        ),
      ],
    );
  }
}
