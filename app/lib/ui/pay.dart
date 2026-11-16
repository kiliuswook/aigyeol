// 검사 1회 결제 화면(시제품: 실제 결제 없음. 앱 출시 때 구글 플레이 결제로 바꿈)
import 'package:material_ui/material_ui.dart';
import '../main.dart';
import '../store.dart';
import 'kit.dart';
import 'links.dart';
import 'test.dart';

const kKind = {'first': '첫 정밀검사', 'cg': '양육자 추가 검사', 'retest': '다시 검사하기'};

Widget priceNote() => rich(
    '아이마다 첫 검사 **${Price.fmt(Price.first)}**, 그 아이의 다른 양육자 검사와 다시 검사하기는 **${Price.fmt(Price.more)}**입니다. 동생·형제는 새 아이로 등록하면 첫 검사 ${Price.fmt(Price.first)}입니다. 자동 결제는 없습니다.',
    style: smallMuted);

class PayScreen extends StatelessWidget {
  final bool retest;
  const PayScreen({super.key, required this.retest});
  @override
  Widget build(BuildContext context) {
    final k = store.payKind(retest), pr = store.kid.nextPrice, nm = store.nm, who = store.kid.who;
    final head = {'first': '$nm의 MBTI를 알아보세요', 'cg': '$who의 눈으로 본 $nm', 'retest': '$nm, 요즘은 어떨까요?'}[k]!;
    final desc = {
      'first': '66문항 정밀검사와 정밀 리포트(기질 결과 + 성격 결과)가 열립니다.',
      'cg': "$nm의 첫 검사는 이미 결제되어 추가 검사 가격입니다. 결과는 리포트의 '양육자 비교' 탭에서 다른 양육자와 나란히 볼 수 있습니다.",
      'retest': "지금 결과를 이전 기록으로 남기고 66문항을 다시 답합니다. 선택지 옆에 지난번 내 답과 다른 양육자의 답이 보이고, 끝나면 '달라진 점' 탭에서 비교합니다.",
    }[k]!;
    return Scaffold(
      body: SafeArea(
        child: AppPage(brand: false, [
          col([eyebrow('${kKind[k]} · $nm · $who'), h1(head)], gap: 6),
          PaperCard([
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(Price.fmt(pr), style: disp(36)),
              const SizedBox(width: 8),
              const Text('검사 1회 · 한 번 결제', style: smallMuted),
            ]),
            p(desc),
            for (final (t, d) in const [
              ('기질 결과.', '네 글자 유형과 별명, 4축, 세부 기질 12가지, 강점과 살펴볼 점, 잘 통하는 말'),
              ('성격 결과.', '경험으로 자라는 끈기, 스스로 힘, 함께 힘'),
              ('계속 보기.', '결과는 기간 없이 계속 볼 수 있고, 결과 카드를 친구·가족에게 공유할 수 있습니다'),
            ])
              rich('· **$t** $d', style: small),
            Btn('${Price.fmt(pr)} 결제하고 검사 시작', () {
              store.buy(retest);
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TestScreen()));
            }),
            priceNote(),
            Row(children: [
              const Expanded(child: Text('시제품이라 실제 결제는 일어나지 않습니다. 앱 출시 때 구글 플레이 결제로 연결됩니다.', style: smallMuted)),
              TextButton(onPressed: openPrivacy, child: const Text('개인정보처리방침')),
            ]),
          ]),
          Btn('나중에 하기', () => Navigator.of(context).pop(), kind: BtnKind.ghost),
        ]),
      ),
    );
  }
}
