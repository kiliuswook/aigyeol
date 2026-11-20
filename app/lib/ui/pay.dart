// 검사 시작 화면: 보상형 광고를 한 번 끝까지 보면 검사가 열린다(2026-11-20 결제 대신 광고). 한 화면, 버튼은 아래에 붙는다.
import 'package:flutter/material.dart';
import '../ads.dart';
import '../store.dart';
import 'kit.dart';
import 'links.dart';
import 'test.dart';

const kKind = {'first': '첫 정밀검사', 'cg': '양육자 추가 검사', 'retest': '다시 검사하기'};

Widget priceNote() => rich(
    '검사는 **무료**입니다. 검사를 시작할 때 **광고 1번**을 끝까지 보면 66문항 정밀검사가 열립니다. 아이마다, 양육자마다, 다시 검사할 때마다 같습니다. 결제는 없습니다.',
    style: small);

Future<void> priceSheet(BuildContext context) => popup(context, title: '이용 안내', (c, set) => [
      priceNote(),
      muted("결과는 기간 없이 계속 볼 수 있습니다. 엄마, 아빠, 할머니처럼 양육자마다 따로 답하면 리포트의 '양육자 비교'에서 서로 다르게 본 점을 정리해 드립니다."),
      muted('앱 아래쪽 배너와 화면을 옮길 때 가끔 나오는 광고로 무료 검사를 이어 갑니다.'),
      Btn('확인', () => Navigator.of(c).pop(), kind: BtnKind.ghost),
    ]);

class PayScreen extends StatefulWidget {
  final bool retest;
  const PayScreen({super.key, required this.retest});
  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  bool busy = false;

  Future<void> go() async {
    if (busy) return;
    setState(() => busy = true);
    final r = await ads.showRewarded();
    if (!mounted) return;
    setState(() => busy = false);
    if (r == RewardResult.skipped) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('광고를 끝까지 보면 검사가 열려요.')));
      return;
    }
    store.buy(widget.retest);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TestScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final retest = widget.retest;
    final k = store.payKind(retest), nm = store.nm, who = store.kid.who;
    final head = {'first': '$nm의 MBTI를 알아보세요', 'cg': '$who의 눈으로 본 $nm', 'retest': '$nm, 요즘은 어떨까요?'}[k]!;
    final desc = {
      'first': '66문항 정밀검사와 정밀 리포트가 열립니다.',
      'cg': "결과는 '양육자 비교'에서 다른 양육자와 나란히 봅니다.",
      'retest': "지금 결과를 이전 기록으로 남기고 다시 답합니다. 끝나면 '달라진 점'에서 비교합니다.",
    }[k]!;
    return Scaffold(
      body: SafeArea(
        child: Frame(
          top: TopBar(kKind[k]!, close: true),
          body: Fit(
              align: Alignment.center,
              col([
                Center(child: Image.asset('assets/img/mascot_child.webp', width: 88, height: 88)),
                col([eyebrow('$nm · $who 답함'), h1(head)], gap: 4),
                PaperCard([
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('무료', style: disp(40)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('광고 1번 보고 검사 · 결제 없음', style: smallMuted)),
                  ]),
                  Text(desc, style: small),
                  for (final (t, d) in const [
                    ('기질 결과', '네 글자 유형, 4축, 세부 기질 12가지, 잘 통하는 말'),
                    ('성격 결과', '끈기, 스스로 힘, 함께 힘'),
                    ('계속 보기', '기간 없이 열람, 결과 카드 공유'),
                  ])
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: Image.asset('assets/ui/i_check.webp', width: 18, height: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: rich('**$t** $d', style: small)),
                    ]),
                ], gap: 10),
              ], gap: 14)),
          foot: [
            Btn(busy ? '광고를 불러오는 중…' : '광고 보고 무료로 검사 시작', go, kind: BtnKind.dark),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              linkBtn('이용 안내', () => priceSheet(context)),
              const SizedBox(width: 16),
              linkBtn('개인정보처리방침', openPrivacy),
            ]),
          ],
        ),
      ),
    );
  }
}
