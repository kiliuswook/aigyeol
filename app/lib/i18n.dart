// 다국어. 설명은 docs/systems/i18n.md
//
// - 코드 안 문구는 한국어 원문 그대로 tr('…')로 감싼다. 원문이 곧 번역 키다.
//   값이 들어가는 자리는 {0}, {1} … 로 쓰고 tr('{0}의 리포트', [nm]) 처럼 넘긴다.
// - 번역은 assets/i18n/<언어>.json: { "한국어 원문": "번역" }. 없는 문구는 한국어 원문이 그대로 보인다.
// - 문항·유형 풀이(content)와 오늘 탭(daily)은 assets/data/content.<언어>.json, daily.<언어>.json (구조는 한국어 파일과 같음).
// - 언어 추가: kLangs 에 한 줄 + 위 세 파일. 처음에는 기기 언어를 따르고, 더보기 > 언어에서 바꿀 수 있다.
import 'dart:convert';
import 'dart:ui' show Locale;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원 언어: 코드 → 그 언어로 쓴 이름. 한국어가 원문.
const kLangs = {'ko': '한국어', 'en': 'English', 'ja': '日本語', 'zh': '中文(简体)', 'zh-Hant': '中文(繁體)', 'es': 'Español', 'vi': 'Tiếng Việt'};

/// 기기 언어가 지원 목록에 없을 때 쓰는 언어(해외 사용자 기본)
const kFallbackLang = 'en';

/// 지금 언어. 바뀌면 앱 전체를 다시 그린다(main.dart).
final lang = ValueNotifier<String>('ko');

/// 사용자가 고른 언어. 비어 있으면 기기 언어를 따른다.
String langPick = '';

Map<String, String> _tr = const {};

String _cur = 'ko';

/// 지금 쓰는 언어 코드
String get langCode => _cur;

bool get isKo => _cur == 'ko';

/// 언어 코드 → Locale (zh-Hant 는 zh_Hant)
Locale localeOf(String c) => c == 'zh-Hant' ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant') : Locale(c);

/// 한국어 원문 [ko]를 지금 언어로. [a]는 {0}, {1} … 자리에 넣을 값.
String tr(String ko, [List<Object?>? a]) {
  var s = isKo ? ko : (_tr[ko] ?? ko);
  if (a != null) {
    for (var i = 0; i < a.length; i++) {
      s = s.replaceAll('{$i}', '${a[i] ?? ''}');
    }
  }
  return s;
}

/// 기기 언어 → 지원 언어
String deviceLang() {
  final loc = PlatformDispatcher.instance.locale;
  final l = loc.languageCode;
  // 중국어: 번체(대만·홍콩·마카오, 또는 Hant 표기)는 zh-Hant, 나머지는 간체
  if (l == 'zh' && (loc.scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(loc.countryCode))) return 'zh-Hant';
  return kLangs.containsKey(l) ? l : kFallbackLang;
}

const _kPref = 'childmbti_lang';

/// 앱을 켤 때: 저장된 선택(없으면 기기 언어)으로 번역을 읽는다. content·daily 는 이 뒤에 읽는다.
Future<void> loadLang() async {
  try {
    langPick = (await SharedPreferences.getInstance()).getString(_kPref) ?? '';
  } catch (_) {}
  await _apply(langPick.isNotEmpty && kLangs.containsKey(langPick) ? langPick : deviceLang());
  lang.value = _cur;
}

/// 더보기 > 언어에서 고를 때. '' 이면 기기 언어를 따른다. [reload]는 content·daily 를 새 언어로 다시 읽는 함수.
Future<void> setLang(String code, Future<void> Function() reload) async {
  langPick = code;
  try {
    final sp = await SharedPreferences.getInstance();
    code.isEmpty ? await sp.remove(_kPref) : await sp.setString(_kPref, code);
  } catch (_) {}
  final l = code.isEmpty ? deviceLang() : code;
  await _apply(l);
  await reload();
  lang.value = l;
}

Future<void> _apply(String l) async {
  Map<String, String> m = const {};
  if (l != 'ko') {
    try {
      m = Map<String, String>.from(jsonDecode(await rootBundle.loadString('assets/i18n/$l.json')));
    } catch (_) {}
  }
  _tr = m;
  _cur = l;
}

/// 언어별 데이터 파일: 한국어는 원래 파일, 다른 언어는 name.<언어>.json (없으면 한국어)
Future<String> loadLocalized(String path) async {
  if (_cur != 'ko') {
    try {
      return await rootBundle.loadString(path.replaceFirst(RegExp(r'\.json$'), '.$_cur.json'));
    } catch (_) {}
  }
  return rootBundle.loadString(path);
}

/// 양육자 이름(저장 값은 한국어 '엄마' 등) → 화면에 보일 이름. 사용자가 적은 이름은 그대로.
String cg(String w) {
  const tail = '(받은 결과)';
  if (w.endsWith(tail)) return tr('{0}(받은 결과)', [tr(w.substring(0, w.length - tail.length))]);
  return tr(w);
}

/// 저장된 나이('만 5세', '만 5세 3개월') → 화면에 보일 나이
String ageTx(String a) {
  if (isKo) return a;
  final m = RegExp(r'만 (\d+)세(?: (\d+)개월)?').firstMatch(a);
  if (m == null) return a;
  return m[2] == null ? tr('만 {0}세', [m[1]]) : tr('만 {0}세 {1}개월', [m[1], m[2]]);
}

/// 문장 안에서 항목을 잇는 쉼표(일본어·중국어는 '、')
String get listSep => const {'ja': '、', 'zh': '、', 'zh-Hant': '、'}[_cur] ?? ', ';
