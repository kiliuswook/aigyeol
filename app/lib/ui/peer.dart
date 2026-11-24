// 또래 평균 공용 조각: 지표 옆 평균 버튼, 수집 중 안내
import 'package:flutter/material.dart';
import '../i18n.dart';
import 'kit.dart';

/// 아직 평균을 보여 줄 만큼 모이지 않았을 때
Widget peerCollecting(String label) => NineBox(nSoft,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(children: [
      peerIcon(26),
      const SizedBox(width: 10),
      Expanded(child: rich(tr('**{0} 평균은 수집 중입니다.** 결과가 모이면 여기에 평균이 나타나요.', [label]), style: small)),
    ]));

/// 돋보기 안에 막대그래프 아이콘(손그림). 그림이 없으면 기본 아이콘.
Widget peerIcon(double s) => Image.asset('assets/ui/i_peer.webp', width: s, height: s,
    errorBuilder: (_, _, _) => Icon(Icons.query_stats_rounded, size: s * .85, color: kAccentInk));

/// 지표 옆 평균 버튼(손그림 테두리 안에 돋보기·그래프 아이콘). 좁은 칸에도 들어가게 글자 없이.
Widget peerBtn(Key key, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Semantics(
      button: true,
      label: tr('또래 평균'),
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: NineBox(nTag, padding: const EdgeInsets.fromLTRB(9, 3, 9, 3), child: peerIcon(22)),
      ),
    ));
