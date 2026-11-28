// 공유(휴대폰 공유 창), 개인정보처리방침 열기, 받은 링크 읽기
import '../i18n.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart' as kk;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../content.dart';
import '../fam.dart';
import '../scoring.dart';
import '../store.dart';
import 'kit.dart';

/// 개인정보처리방침: 한국어는 privacy.html?hl=ko, 다른 언어는 privacy-<언어>.html (번체는 zh 판)
String privacyUrl() => isKo ? '${kSite}privacy.html?hl=ko' : '${kSite}privacy-${langCode.split('-').first}.html';

Future<void> openPrivacy() => launchUrl(Uri.parse(privacyUrl()), mode: LaunchMode.externalApplication);

/// 공유 문구. kind: result 결과 카드, invite 공동 양육자 초대, back 초대한 사람에게 결과 보내기, app 앱 추천
/// 주소는 모두 스토어로 이어지는 연결 페이지(Store.go). 초대는 가족 연결 코드([code], fam.dart)가 있으면 코드로, 없으면 예전 방식(아이 정보를 실은 링크).
(String title, String text, String url) shareMsg(String kind, {String role = '', String? code}) {
  final k = store.kid, nm = store.nm;
  switch (kind) {
    case 'result':
      final code = score(store.cur.ans).code;
      return (tr("우리 아이는 {0} '{1}'", [code, C.nick[code]]), tr('만 2~7세 아이 기질을 MBTI처럼 네 글자로. 우리 아이 MBTI도 알아보세요.'), Store.typeUrl(code));
    case 'invite':
      final t = tr('{0}의 눈으로 본 {1}는 어떤 아이일까요? 따로 답하고 결과를 나란히 비교해요.', [cg(role), nm]);
      if (code == null) return (tr('{0} {1} 기질검사에 초대했어요', [ga(cg(k.who)), nm]), t, store.inviteUrl(role));
      return (
        tr('{0} {1} 기질검사에 초대했어요', [ga(cg(k.who)), nm]),
        '$t\n${tr('초대 코드 {0} · 앱을 설치한 뒤 더보기의 \'초대 코드 입력\'에 넣어도 됩니다.', [Fam.show(code)])}',
        Store.famUrl(code, role)
      );
    case 'back':
      return (tr('{0} {1} 검사 결과를 보냈어요', [ga(cg(k.who)), nm]), tr("{0}의 휴대폰에서 열면 '양육자 비교'에 합쳐집니다.", [cg(k.inv?['from'] ?? '가족')]), store.backUrl());
    default:
      return (tr('내 아이의 MBTI · 영유아 기질검사'), tr('부모가 답하는 만 2~7세 기질검사. 우리 아이는 어떤 네 글자일까요?'), Store.appUrl);
  }
}

/// 받침이 있으면 '이', 없으면 '가'
String ga(String w) {
  if (w.isEmpty || !isKo) return w;
  final c = w.codeUnitAt(w.length - 1);
  return w + ((c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0) ? '이' : '가');
}

/// 휴대폰 공유 창으로 보낸다. [image]가 있으면 그림(결과 화면 캡처)도 함께.
Future<void> doShare(BuildContext ctx, String kind, {String role = '', String? code, Uint8List? image}) async {
  final (title, text, url) = shareMsg(kind, role: role, code: code);
  await SharePlus.instance.share(ShareParams(
    text: '$title\n$text\n$url',
    subject: title,
    files: image == null ? null : [XFile.fromData(image, mimeType: 'image/png', name: 'childmbti.png')],
    fileNameOverrides: image == null ? null : ['childmbti.png'],
  ));
}

/// 화면 한 부분(RepaintBoundary 의 [key])을 PNG 그림으로. 못 찍으면 null.
Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 3}) async {
  try {
    final b = key.currentContext?.findRenderObject();
    if (b is! RenderRepaintBoundary) return null;
    final img = await b.toImage(pixelRatio: pixelRatio);
    final d = await img.toByteData(format: ui.ImageByteFormat.png);
    return d?.buffer.asUint8List();
  } catch (e) {
    debugPrint('capture: $e');
    return null;
  }
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
      'invite' => tr('검사하러 가기'),
      'back' => tr('결과 합치기'),
      'result' => tr('우리 아이도 검사하기'),
      _ => tr('앱 보러 가기'),
    };

/// 카카오톡으로 보낸다.
/// 1) 카카오 SDK 카드 공유(그림·제목·버튼). 2) 카카오톡 앱을 못 쓰는 곳(PC 브라우저, 카카오톡 없는 휴대폰)은
/// 카카오 웹 공유 창으로 같은 카드를 보낸다. 3) 안 되면 카카오톡에 글+링크로 바로 보내기(안드로이드, 앱 키 불필요).
/// 4) 그것도 안 되면 휴대폰 공유 창.
Future<void> doKakao(BuildContext ctx, String kind, {String role = '', String? code, Uint8List? image}) async {
  final (title, text, url) = shareMsg(kind, role: role, code: code);
  final u = Uri.parse(url);
  // 결과 화면 캡처가 있으면 카카오 서버에 올려 카드 그림으로 쓴다(못 올리면 기본 그림)
  var img = Uri.parse('${kSite}assets/og_v2.png');
  int? iw, ih;
  if (image != null) {
    try {
      final up = await kk.ShareClient.instance.uploadImage(byteData: image);
      img = Uri.parse(up.infos.original.url);
      iw = up.infos.original.width;
      ih = up.infos.original.height;
    } catch (e) {
      debugPrint('kakao upload: $e');
    }
  }
  final tpl = kk.FeedTemplate(
    content: kk.Content(title: title, description: text, imageUrl: img, imageWidth: iw, imageHeight: ih, link: kk.Link(webUrl: u, mobileWebUrl: u)),
    buttons: [kk.Button(title: _btnTitle(kind), link: kk.Link(webUrl: u, mobileWebUrl: u))],
  );
  try {
    if (await kk.ShareClient.instance.isKakaoTalkSharingAvailable()) {
      await kk.ShareClient.instance.shareDefault(template: tpl);
      return;
    }
  } catch (e) {
    debugPrint('kakao share: $e');
  }
  try {
    final w = await kk.WebSharerClient.instance.makeDefaultUrl(template: tpl);
    if (await launchUrl(w, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank')) return;
  } catch (e) {
    debugPrint('kakao web share: $e');
  }
  var ok = false;
  if (!kIsWeb) {
    try {
      ok = await _shareCh.invokeMethod<bool>('kakao', {'text': '$title\n$text\n$url'}) ?? false;
    } catch (_) {}
  }
  if (ok) return;
  if (ctx.mounted) toast(ctx, tr('카카오톡을 열 수 없어 공유 창으로 보냅니다.'));
  if (ctx.mounted) await doShare(ctx, kind, role: role, code: code, image: image);
}

/// 받은 링크(초대·결과·유형·앱 추천)를 읽는다. 값은 주소의 # 뒤(예전 ? 링크도 읽음).
class Landing {
  final String kind; // fam 가족 연결 코드, inv, res, type, app
  final Map? d;
  final String? code;
  /// fam: 초대한 사람이 고른 역할(링크에 실려 온 경우)
  final String? role;
  Landing(this.kind, {this.d, this.code, this.role});

  static Landing? parse(String link) {
    final u = Uri.tryParse(link.trim());
    if (u == null) return null;
    final h = u.fragment;
    final q = RegExp(r'^[icrtf]=').hasMatch(h) ? Uri.splitQueryString(h) : u.queryParameters;
    if (q['f'] != null) {
      final c = Fam.norm(q['f']!);
      if (c != null) return Landing('fam', code: c, role: q['w']);
    }
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
