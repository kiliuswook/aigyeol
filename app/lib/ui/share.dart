// 함께 보기: 가족 초대·결과 보내기·결과 카드 공유·앱 추천. 더보기 탭 위쪽에 칸으로 놓이고, 보내기는 팝업에서.
import '../i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../content.dart';
import '../fam.dart';
import 'land.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';
import 'links.dart';
import 'setup.dart' show askCgName;

/// 함께 보기 칸 하나
typedef ShareItem = ({String title, String icon, VoidCallback? onTap});

/// 함께 보기 칸 하나의 창을 바로 연다(결과 공유·결과 보내기). 더보기 탭으로 옮기지 않는다.
void openShare(BuildContext context, String title) {
  for (final e in const ShareActions().items(context)) {
    if (e.title == title) return e.onTap?.call();
  }
}

class ShareActions {
  const ShareActions();

  // 카카오톡 · 다른 앱 · 링크 복사를 한 줄로.
  // [code]: 초대할 때 가족 연결 코드를 받아 오는 함수(fam.ensure). [image]: 함께 보낼 그림(결과 화면 캡처)을 만드는 함수.
  Widget buttons(BuildContext context, String kind, {String Function()? role, Future<String?> Function()? code, Future<Uint8List?> Function()? image}) {
    Future<(String, String?, Uint8List?)> args() async => (role?.call() ?? '', await code?.call(), await image?.call());
    return Row(children: [
        // 카카오톡은 한국어일 때만. 다른 언어에서는 휴대폰 공유 창(왓츠앱·라인·메시지 등)을 앞에 둔다.
        if (isKo) ...[
          Expanded(flex: 13, child: KakaoBtn(() async {
            final (r, c, i) = await args();
            if (context.mounted) await doKakao(context, kind, role: r, code: c, image: i);
          }, label: tr('카카오톡'))),
          const SizedBox(width: 8),
          Expanded(flex: 10, child: Btn(tr('다른 앱'), () async {
            final (r, c, i) = await args();
            if (context.mounted) await doShare(context, kind, role: r, code: c, image: i);
          }, kind: BtnKind.ghost, dense: true)),
        ] else
          Expanded(flex: 13, child: Btn(tr('공유하기'), () async {
            final (r, c, i) = await args();
            if (context.mounted) await doShare(context, kind, role: r, code: c, image: i);
          }, dense: true)),
        const SizedBox(width: 8),
        Expanded(
            flex: 11,
            child: Btn(tr('링크 복사'), () async {
              final r = role?.call() ?? '', c = await code?.call();
              final (_, text, url) = shareMsg(kind, role: r, code: c);
              // 초대는 코드 안내까지 함께 복사한다(아이폰은 앱을 설치한 뒤 코드를 넣어야 이어진다)
              await Clipboard.setData(ClipboardData(text: c != null ? '$text\n$url' : url));
              if (context.mounted) {
                Navigator.of(context).pop();
                toast(context, tr('링크를 복사했습니다. 카카오톡이나 문자에 붙여 넣어 보내 주세요.'));
              }
            }, kind: BtnKind.ghost, dense: true)),
      ]);
  }

  List<ShareItem> items(BuildContext context) {
    final kid = store.kid, cur = store.cur;
    final r = fullDone(cur.ans) && cur.paid ? score(cur.ans) : null;
    final from = '${kid.inv?['from'] ?? tr('가족')}';
    return [
        // 가족 연결 코드로 이어진 아이는 결과가 저절로 합쳐져 따로 보낼 필요가 없다
        if (kid.inv != null && kid.fam.isEmpty && r != null)
          (title: tr('결과 보내기'), icon: 'i_send',
              onTap: () => popup(context, title: tr('결과 보내기'), (c, set) => [
                    muted(tr("{0}의 휴대폰 '양육자 비교'에 합쳐집니다. 결과 링크에는 아이 이름·연령과 답이 실립니다.", [from])),
                    buttons(c, 'back'),
                  ])),
        (title: tr('양육자 초대'), icon: 'i_heart', onTap: () => inviteCg(context)),
        (title: tr('결과 공유'), icon: 'i_share', onTap: r == null ? null : () => shareResult(context)),
        (title: tr('앱 추천'), icon: 'i_star', onTap: () => popup(context, title: tr('친구에게 앱 추천하기'), (c, set) => [buttons(c, 'app')])),
    ];
  }
}

/// 양육자 초대 창: 누구를 초대할지 고르고 카카오톡 · 다른 앱 · 링크 복사로 보낸다.
/// 더보기 '양육자 초대', 리포트 '다른 휴대폰으로 초대 보내기', 홈 '가족 초대', '답하는 사람 추가' 창의 초대 버튼이 모두 이 창을 바로 연다.
Future<void> inviteCg(BuildContext context) {
  final kid = store.kid, nm = store.nm;
  final roles = kCgl.where((n) => n != kid.who).toList();
  var role = roles.first;
  return popup(context, title: tr('다른 휴대폰에서 {0} 검사하게 초대', [nm]), (c, set) => [
        muted(tr('누구를 초대하나요?')),
        chips([
          for (final n in roles.where((n) => n != kOtherCg)) ChipBtn(cg(n), on: role == n, onTap: () => set(() => role = n)),
          // '기타 양육자' 는 초대할 사람의 이름을 직접 적는다
          ChipBtn(cg(roles.contains(role) && role != kOtherCg ? kOtherCg : role), on: !roles.contains(role) || role == kOtherCg, onTap: () async {
            final n = await askCgName(c, initial: roles.contains(role) ? '' : role, taken: {kid.who});
            if (n != null) set(() => role = n);
          }),
        ]),
        const ShareActions().buttons(c, 'invite', role: () => role, code: () async {
          final code = await fam.ensure(kid);
          if (code == null && c.mounted) toast(c, tr('인터넷 연결이 없어 예전 방식 링크로 보냅니다. 결과는 링크로 주고받아요.'));
          return code;
        }),
        muted(tr("받은 사람은 링크를 눌러 앱을 설치하면 {0}의 검사로 바로 들어갑니다. 광고 1번 보고 무료로 검사하고, 다 마치면 결과가 이 휴대폰의 '양육자 비교'에 저절로 합쳐집니다.", [nm])),
        muted(tr('아이폰은 앱을 설치한 뒤 초대 문구의 초대 코드를 더보기의 \'초대 코드 입력\'에 넣으면 이어집니다. 아이 이름·연령이 함께 가니 믿을 수 있는 가족에게만 보내 주세요.')),
      ]);
}

/// 초대 코드 입력: 아이폰처럼 설치 정보로 초대가 이어지지 않을 때. 초대 문구 전체를 붙여 넣어도 코드를 찾는다.
Future<void> enterCode(BuildContext context) {
  final ctl = TextEditingController();
  String? err;
  return popup(context, title: tr('초대 코드 입력'), (c, set) => [
        muted(tr('가족이 보낸 초대 문구의 초대 코드(예: ABCDE-FGH23)를 넣어 주세요.')),
        PaperField(ctl, hint: 'ABCDE-FGH23', maxLength: 400),
        if (err != null) Text(err!, style: smallMuted),
        Row(children: [
          Expanded(child: Btn(tr('붙여 넣기'), () async {
            final d = await Clipboard.getData(Clipboard.kTextPlain);
            final f = Fam.find(d?.text ?? '');
            set(() => f != null ? ctl.text = Fam.show(f) : err = tr('복사한 글에서 초대 코드를 찾지 못했어요.'));
          }, kind: BtnKind.ghost, dense: true)),
          const SizedBox(width: 8),
          Expanded(child: Btn(tr('확인'), () {
            final f = Fam.find(ctl.text);
            if (f == null) return set(() => err = tr('초대 코드는 영문·숫자 10자리예요. 다시 확인해 주세요.'));
            Navigator.of(c).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LandScreen(Landing('fam', code: f))));
          }, kind: BtnKind.dark, dense: true)),
        ]),
      ]);
}

/// 결과 공유: 결과 화면(유형·별명·네 축)을 그림으로 찍어 링크와 함께 보낸다. 창에 보이는 카드가 그대로 그림이 된다.
Future<void> shareResult(BuildContext context) {
  final key = GlobalKey();
  var withName = false;
  return popup(context, title: tr('결과 공유'), (c, set) => [
        RepaintBoundary(key: key, child: ResultCard(withName: withName)),
        if (store.kid.name.isNotEmpty)
          chips([
            ChipBtn(tr('아이 이름 빼기'), on: !withName, onTap: () => set(() => withName = false)),
            ChipBtn(tr('아이 이름 넣기'), on: withName, onTap: () => set(() => withName = true)),
          ]),
        muted(tr('이 카드 그림과 앱 설치 링크를 함께 보냅니다. 답한 내용은 보내지 않습니다.')),
        const ShareActions().buttons(c, 'result', image: () => capture(key)),
      ]);
}

/// 공유용 결과 카드: 리포트 첫 화면처럼 유형 캐릭터·네 글자·별명·네 축 막대, 아래에 앱 이름.
class ResultCard extends StatelessWidget {
  final bool withName;
  const ResultCard({super.key, this.withName = false});
  @override
  Widget build(BuildContext context) {
    final r = score(store.cur.ans), nm = store.nm;
    return Container(
      color: kBg,
      padding: const EdgeInsets.all(6),
      child: NineBox(nCard,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: col(gap: 7, [
            Row(children: [
              mascot(r.code, size: 78),
              const SizedBox(width: 10),
              Expanded(
                  child: col([
                eyebrow(withName ? tr('{0}의 MBTI', [nm]) : tr('우리 아이 MBTI')),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: codeText([for (final x in r.ax) (x.letter, x.a.color)], size: 36)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(C.nick[r.code]!, style: disp(20))),
              ], gap: 0, x: CrossAxisAlignment.start)),
            ]),
            for (final x in r.ax) axisBar(x.a, x.sc, thin: true),
            Row(children: [
              Image.asset('assets/img/mascot_child.webp', width: 22, height: 22),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('내 아이의 MBTI · 만 2~7세 기질검사'), maxLines: 1, overflow: TextOverflow.ellipsis, style: smallMuted)),
            ]),
          ])),
    );
  }
}
