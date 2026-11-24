// 더보기: 함께 보기(초대·공유) + 계정·가격·기록 지우기 + 만든 사람. 한 화면.
import '../i18n.dart';
import 'package:flutter/material.dart';
import '../ads.dart';
import '../main.dart';
import '../store.dart';
import '../sync.dart';
import 'account.dart';
import 'kit.dart';
import 'share.dart';
import 'today.dart' show alarmPopup;
import '../daily.dart';
import '../dev.dart';
import '../content.dart';
import '../notify.dart';
import 'pay.dart';
import '../upgrade.dart';

/// 언어 고르기. 처음에는 휴대폰 언어를 따른다.
Future<void> langPopup(BuildContext context) => popup(context, title: langCode == 'en' ? 'Language' : '${tr('언어')} · Language', (c, set) => [
      chips([
        ChipBtn(tr('휴대폰 언어 따르기'), on: langPick.isEmpty, onTap: () => _pick(c, '')),
        for (final e in kLangs.entries) ChipBtn(e.value, on: langPick == e.key, onTap: () => _pick(c, e.key)),
      ]),
    ]);

Future<void> _pick(BuildContext c, String code) async {
  Navigator.of(c).pop();
  await setLang(code, () async {
    await Future.wait([loadContent(), loadDaily(), loadDev()]);
  });
  // 알림 문구도 새 언어로 다시 건다
  await notify.reschedule();
}

class MoreView extends StatelessWidget {
  const MoreView({super.key});

  Future<void> reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('{0}의 기록을 지울까요?', [store.nm])),
        content: Text(tr('이 아이의 검사 답과 검사 기록이 이 휴대폰에서 모두 지워집니다. 되돌릴 수 없어요.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('취소'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('지우기'), style: TextStyle(color: Color(0xFFC0392B)))),
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
      top: tabTitle(tr('더보기')),
      body: Fit(col([
        eyebrow(tr('함께 보기')),
        Row(children: [
          for (var i = 0; i < sh.length; i++) ...[if (i > 0) const SizedBox(width: 6), cell(sh[i])],
        ]),
        Tile(tr('초대 코드 입력'), icon: 'i_send', sub: tr('가족에게 받은 초대를 이어서 검사해요'), onTap: () => enterCode(context)),
        eyebrow(tr('내 정보')),
        ListenableBuilder(
            listenable: sync,
            builder: (context, _) {
              final (t, d) = !sync.signedIn
                  ? (tr('메일로 로그인·가입'), tr('휴대폰을 바꿔도 기록이 이어져요 (선택)'))
                  : !sync.verified
                      ? (tr('메일 인증이 남았어요'), sync.email)
                      : (tr('내 계정 · 동기화 중'), sync.email);
              return Tile(t, icon: 'i_lock', sub: d, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())));
            }),
        if (notify.supported)
          ListenableBuilder(
              listenable: daily,
              builder: (context, _) => Tile(tr('푸시 알림'), icon: 'i_bulb',
                  sub: daily.anyAlarm ? [if (daily.alarm) tr('미션 오전 9시'), if (daily.eve) tr('저녁 확인'), if (daily.planAlarm) tr('약속 하루 전·1시간 전')].join(' · ') : tr('꺼짐'),
                  onTap: () => alarmPopup(context))),
        Tile(tr('이용 안내'), icon: 'i_bulb', sub: tr('검사는 광고 1번 보고 무료'), onTap: () => priceSheet(context)),
        // 언어: 다른 언어로 잘못 바뀌어도 찾을 수 있게 영어 이름을 함께 적는다
        Tile(langCode == 'en' ? 'Language' : '${tr('언어')} · Language', icon: 'i_chat', sub: langPick.isEmpty ? tr('{0} (휴대폰 언어)', [kLangs[langCode]]) : kLangs[langCode], onTap: () => langPopup(context)),
        // 유럽·영국 등 광고 동의가 필요한 곳에서만 보인다
        FutureBuilder<bool>(
            future: ads.privacyOptionsRequired(),
            builder: (context, s) => s.data == true
                ? Tile(tr('광고 개인정보 설정'), icon: 'i_lock', sub: tr('맞춤 광고 동의 바꾸기'), onTap: ads.showPrivacyOptions)
                : const SizedBox.shrink()),
        Tile(tr('앱 평가하기'), icon: 'i_star', sub: tr('별점과 한 줄 후기가 큰 힘이 돼요'), onTap: upgrade.openStore),
        Tile(tr('{0}의 기록 지우기', [store.nm]), icon: 'i_close', sub: tr('이 휴대폰에서 이 아이의 기록 초기화'), onTap: () => reset(context)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(tr('양육 참고용이며 의학적 진단이 아닙니다. 검사는 광고를 보고 무료로 이용합니다.'), style: smallMuted),
        ),
      ], gap: 8)),
      // 만든 사람
      foot: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/img/wonderwheel.png', height: 34, errorBuilder: (_, _, _) => const SizedBox()),
            const SizedBox(width: 8),
            Text(tr('만든 사람'), style: TextStyle(fontSize: 12.5, color: kMuted)),
            const SizedBox(width: 6),
            Text(tr('원더휠 WonderWheel'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kFg)),
          ])),
        ),
      ],
    );
  }
}
