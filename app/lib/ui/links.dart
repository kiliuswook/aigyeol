// 공유(휴대폰 공유 창), 개인정보처리방침 열기, 기록 파일 저장·불러오기, 받은 링크 읽기
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart' as kk;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../content.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';

Future<void> openPrivacy() => launchUrl(Uri.parse('${kSite}privacy.html'), mode: LaunchMode.externalApplication);

/// 공유 문구. kind: result 결과 카드, invite 공동 양육자 초대, back 초대한 사람에게 결과 보내기, app 앱 추천
(String title, String text, String url) shareMsg(String kind, {String role = ''}) {
  final k = store.kid, nm = store.nm;
  switch (kind) {
    case 'result':
      final code = score(store.cur.ans).code;
      return ("우리 아이는 $code '${C.nick[code]}'", '만 2~7세 아이 기질을 MBTI처럼 네 글자로. 우리 아이 MBTI도 알아보세요.', Store.typeUrl(code));
    case 'invite':
      return ('${ga(k.who)} $nm 기질검사에 초대했어요', '$role의 눈으로 본 $nm는 어떤 아이일까요? 따로 답하고 결과를 나란히 비교해요.', store.inviteUrl(role));
    case 'back':
      return ('${ga(k.who)} $nm 검사 결과를 보냈어요', "${k.inv?['from'] ?? '가족'}의 휴대폰에서 열면 '양육자 비교'에 합쳐집니다.", store.backUrl());
    default:
      return ('내 아이의 MBTI · 영유아 기질검사', '부모가 답하는 만 2~7세 기질검사. 우리 아이는 어떤 네 글자일까요?', Store.appUrl);
  }
}

/// 받침이 있으면 '이', 없으면 '가'
String ga(String w) {
  if (w.isEmpty) return w;
  final c = w.codeUnitAt(w.length - 1);
  return w + ((c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0) ? '이' : '가');
}

/// 휴대폰 공유 창으로 보낸다.
Future<void> doShare(BuildContext ctx, String kind, {String role = ''}) async {
  final (title, text, url) = shareMsg(kind, role: role);
  await SharePlus.instance.share(ShareParams(text: '$title\n$text\n$url', subject: title));
}

const _shareCh = MethodChannel('childmbti/share');

/// 카카오 개발자 콘솔 앱 '내 아이의 MBTI'(ID 1656799)의 키. 둘 다 공개되는 값이다(앱·웹 코드에 들어감).
/// 네이티브 키는 패키지 이름·키 해시(플레이 앱 서명 키, 업로드 키)가 등록된 앱에서만,
/// JavaScript 키는 등록된 도메인에서만 쓸 수 있다. 설정 docs/systems/kakao-share.md
const kKakaoNativeKey = '29136e8e9e21e8bbdab28bceee0dbd57';
const kKakaoJsKey = '7f384e7c7f27f5981b1e8dd43f5953ff';

void initKakao() => kk.KakaoSdk.init(nativeAppKey: kKakaoNativeKey, javaScriptAppKey: kKakaoJsKey);

/// 공유 카드 버튼 글자
String _btnTitle(String kind) => switch (kind) {
      'invite' => '검사하러 가기',
      'back' => '결과 합치기',
      'result' => '우리 아이도 검사하기',
      _ => '앱 보러 가기',
    };

/// 카카오톡으로 보낸다.
/// 1) 카카오 SDK 카드 공유(그림·제목·버튼). 2) 안 되면 카카오톡에 글+링크로 바로 보내기(앱 키 불필요).
/// 3) 카카오톡이 없으면 휴대폰 공유 창.
Future<void> doKakao(BuildContext ctx, String kind, {String role = ''}) async {
  final (title, text, url) = shareMsg(kind, role: role);
  final u = Uri.parse(url);
  try {
    if (await kk.ShareClient.instance.isKakaoTalkSharingAvailable()) {
      await kk.ShareClient.instance.shareDefault(
          template: kk.FeedTemplate(
        content: kk.Content(title: title, description: text, imageUrl: Uri.parse('${kSite}assets/og.png'), link: kk.Link(webUrl: u, mobileWebUrl: u)),
        buttons: [kk.Button(title: _btnTitle(kind), link: kk.Link(webUrl: u, mobileWebUrl: u))],
      ));
      return;
    }
  } catch (e) {
    debugPrint('kakao share: $e');
  }
  var ok = false;
  if (!kIsWeb) {
    try {
      ok = await _shareCh.invokeMethod<bool>('kakao', {'text': '$title\n$text\n$url'}) ?? false;
    } catch (_) {}
  }
  if (ok) return;
  if (ctx.mounted) toast(ctx, '카카오톡을 열 수 없어 공유 창으로 보냅니다.');
  if (ctx.mounted) await doShare(ctx, kind, role: role);
}

Future<void> saveBackup(BuildContext ctx) async {
  final bytes = utf8.encode(store.exportBackup());
  final name = '내아이의MBTI_기록_${today().replaceAll('.', '')}.json';
  await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)], fileNameOverrides: [name], subject: '내 아이의 MBTI 기록 파일'));
}

Future<void> loadBackup(BuildContext ctx) async {
  final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (r.isEmpty) return;
  final b = await r.first.readAsBytes();
  final ok = store.importBackup(utf8.decode(b));
  if (ctx.mounted) toast(ctx, ok ? '기록을 불러왔습니다.' : '이 파일은 불러올 수 없습니다.');
}

/// 받은 링크(초대·결과·유형·앱 추천)를 읽는다. 값은 주소의 # 뒤(예전 ? 링크도 읽음).
class Landing {
  final String kind; // inv, res, type, app
  final Map? d;
  final String? code;
  Landing(this.kind, {this.d, this.code});

  static Landing? parse(String link) {
    final u = Uri.tryParse(link.trim());
    if (u == null) return null;
    final h = u.fragment;
    final q = RegExp(r'^[icrt]=').hasMatch(h) ? Uri.splitQueryString(h) : u.queryParameters;
    if (q['i'] != null) {
      final d = Store.b64d(q['i']!);
      if (d != null && d['k'] != null) return Landing('inv', d: d);
    }
    if (q['c'] != null) {
      final d = Store.b64d(q['c']!);
      if (d != null && d['k'] != null && d['x'] != null) return Landing('res', d: d);
    }
    if (q['t'] != null && C.nick.containsKey(q['t'])) return Landing('type', code: q['t']);
    if (q['r'] != null) return Landing('app');
    return null;
  }
}
