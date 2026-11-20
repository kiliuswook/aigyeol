// 계정 화면: 메일 인증 로그인(선택)과 동기화, 로그아웃, 계정 삭제
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../store.dart';
import '../sync.dart';
import 'kit.dart';
import 'links.dart';

Future<void> openDeletePage() => launchUrl(Uri.parse('${kSite}delete-account.html'), mode: LaunchMode.externalApplication);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountState();
}

class _AccountState extends State<AccountScreen> {
  final mail = TextEditingController(), pw = TextEditingController();
  bool joining = false;

  Future<void> run(Future<String?> f, [String? ok]) async {
    final err = await f;
    if (!mounted) return;
    if (err != null) {
      toast(context, err);
    } else if (ok != null) {
      toast(context, ok);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: sync,
        builder: (context, _) => Frame(
          top: TopBar(!sync.signedIn ? (joining ? '메일로 가입' : '메일로 로그인') : '내 계정'),
          body: Fit(col([
            if (!sync.ready)
              PaperCard([p('이 기기에서는 로그인과 동기화를 쓸 수 없어요. 안드로이드 앱에서 이용해 주세요.')])
            else if (!sync.signedIn)
              ..._signIn()
            else if (!sync.verified)
              ..._verify()
            else
              ..._signedIn(),
            Align(alignment: Alignment.centerLeft, child: linkBtn('개인정보처리방침', openPrivacy)),
          ])),
        ),
      ),
    ),
  );

  List<Widget> _signIn() => [
    PaperCard([
      muted(joining ? '가입하면 인증 메일을 보내 드려요. 메일의 링크를 누르면 이 휴대폰의 기록이 계정에 저장됩니다.' : '가입한 메일로 로그인하면 계정에 저장된 기록과 이 휴대폰의 기록을 합칩니다.'),
      PaperField(mail, hint: '메일 주소', maxLength: 100, keyboard: TextInputType.emailAddress),
      PaperField(pw, hint: joining ? '비밀번호(6자 이상)' : '비밀번호', maxLength: 64, obscure: true),
      Btn(
        joining ? '가입하고 인증 메일 받기' : '로그인',
        sync.busy ? null : () => run(joining ? sync.signUp(mail.text, pw.text) : sync.signIn(mail.text, pw.text), joining ? '인증 메일을 보냈어요.' : null),
        kind: BtnKind.dark,
      ),
      Row(
        children: [
          TextButton(onPressed: () => setState(() => joining = !joining), child: Text(joining ? '이미 가입했어요' : '처음이에요, 가입할게요')),
          const Spacer(),
          if (!joining)
            TextButton(
              onPressed: () => mail.text.trim().isEmpty ? toast(context, '메일 주소를 먼저 적어 주세요.') : run(sync.resetPw(mail.text), '비밀번호를 다시 정하는 메일을 보냈어요.'),
              child: const Text('비밀번호 찾기'),
            ),
        ],
      ),
    ]),
    muted('로그인하면 메일 주소와 검사 기록(아이 별명·태어난 해와 달, 답)이 서버(구글 Firebase, 서울)에 저장됩니다. 계정을 지우면 서버의 기록도 함께 지워집니다.'),
  ];

  List<Widget> _verify() => [
    PaperCard([
      p('${sync.email} 로 인증 메일을 보냈어요. 메일의 링크를 누른 뒤 아래 버튼을 눌러 주세요. 메일이 안 보이면 스팸함도 확인해 주세요.'),
      Btn('인증했어요', sync.busy ? null : () => run(sync.checkVerified(), '인증됐어요. 기록을 동기화했습니다.'), kind: BtnKind.dark),
      Btn('인증 메일 다시 보내기', sync.busy ? null : () => run(sync.resend(), '인증 메일을 다시 보냈어요.'), kind: BtnKind.ghost),
      Btn('로그아웃', sync.signOut, kind: BtnKind.ghost),
    ]),
  ];

  List<Widget> _signedIn() => [
    PaperCard([
      eyebrow('로그인한 메일'),
      h3(sync.email),
      muted(sync.lastError ?? (sync.lastSync != null ? '마지막 동기화 ${_hm(sync.lastSync!)} · 아이 ${store.kids.length}명' : '동기화 준비 중')),
      Btn(
        '지금 동기화',
        sync.busy
            ? null
            : () => run(
                Future(() async {
                  await sync.pull();
                  return sync.lastError;
                }),
                '동기화했어요.',
              ),
        kind: BtnKind.ghost,
      ),
      Btn('로그아웃', () async {
        await sync.signOut();
        if (mounted) toast(context, '로그아웃했어요. 이 휴대폰의 기록은 그대로 남아 있어요.');
      }, kind: BtnKind.ghost),
    ]),
    PaperCard([
      h3('계정 삭제'),
      muted('계정과 서버에 저장된 검사 기록이 모두 지워지고 되돌릴 수 없습니다. 이 휴대폰 안의 기록은 남으며, 더보기의 기록 지우기로 지울 수 있어요.'),
      Btn('계정 삭제', () => _delete(), kind: BtnKind.ghost),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: openDeletePage, child: const Text('앱 없이 웹에서 삭제하기')),
      ),
    ]),
  ];

  Future<void> _delete() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('계정을 삭제할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('확인을 위해 비밀번호를 적어 주세요. 삭제하면 되돌릴 수 없어요.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              obscureText: true,
              decoration: const InputDecoration(hintText: '비밀번호'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (ok == true) await run(sync.deleteAccount(ctl.text), '계정과 서버의 기록을 삭제했어요.');
  }

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
