// 더보기: 계정·기록 옮기기·가격·방침. 줄 메뉴 한 화면.
import 'package:flutter/material.dart';
import '../main.dart';
import '../store.dart';
import '../sync.dart';
import 'account.dart';
import 'kit.dart';
import 'links.dart';
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

  @override
  Widget build(BuildContext context) => Frame(
        top: tabTitle('더보기'),
        body: Fit(col([
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
          Tile('기록 파일 저장', icon: 'i_doc', sub: '로그인 없이 새 휴대폰으로 옮기기', onTap: () => saveBackup(context)),
          Tile('기록 불러오기', icon: 'i_retry', sub: '저장해 둔 기록 파일 열기', onTap: () => loadBackup(context)),
          Tile('가격 안내', icon: 'i_bulb', sub: '첫 검사 ${Price.fmt(Price.first)} · 추가 검사 ${Price.fmt(Price.more)}', onTap: () => priceSheet(context)),
          Tile('개인정보처리방침', icon: 'i_check', onTap: openPrivacy),
          Tile('${store.nm}의 기록 지우기', icon: 'i_close', sub: '이 휴대폰에서 이 아이의 기록 초기화', onTap: () => reset(context)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text('양육 참고용이며 의학적 진단이 아닙니다. 공개 테스트 중이라 결제 버튼을 누르면 실제 결제 없이 검사가 열립니다.', style: smallMuted),
          ),
        ], gap: 10)),
      );
}
