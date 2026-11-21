// 가족 연결(공동 양육자 초대). 설명 docs/systems/share-links.md
//
// 초대할 때 서버(Firestore fam/{코드})에 아이 정보와 이 휴대폰의 양육자 결과를 올리고, 초대 링크·문구에 코드를 싣는다.
// 받은 사람이 앱을 설치해 코드로 들어오면(링크·설치 정보·직접 입력) 같은 아이로 연결되고,
// 그 뒤로는 양쪽 휴대폰의 양육자별 결과가 서버를 거쳐 자동으로 합쳐진다(결과 링크를 다시 보낼 필요 없음).
//
// - 로그인 없이 쓴다. 코드(32글자 중 10자리, 약 10^15가지)를 아는 사람만 그 문서를 읽고 쓸 수 있다(목록 보기는 막힘).
//   초대 링크에 아이 이름·연령이 실리던 것과 같은 수준이다. 규칙은 저장소 firestore.rules 의 fam.
// - 문서: {k: 아이 key, n: 이름, a: 연령, b: 생년월, s: 성별, f: 초대한 양육자, p: 첫 검사 여부, at: 만든 때,
//          recs: {양육자 이름: {x: 66문항 답(Store.encA), d: 검사일, t: 바뀐 때(ms)}}}
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'scoring.dart';
import 'store.dart';
import 'sync.dart';

/// 코드에 쓰는 글자(헷갈리는 0·O·1·I 는 뺌)
const _abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
final _codeRe = RegExp('^[$_abc]{10}\$');

class Fam {
  /// 'ABCDE-FGHJK', 'abcde fghjk' 처럼 적은 것도 코드로 읽는다. 아니면 null.
  static String? norm(String s) {
    final c = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return _codeRe.hasMatch(c) ? c : null;
  }

  /// 글 속에서 코드를 찾는다(복사한 초대 문구 전체를 붙여 넣어도 되게)
  static String? find(String text) {
    for (final m in RegExp('[$_abc]{5}[- ]?[$_abc]{5}').allMatches(text.toUpperCase())) {
      final c = norm(m[0]!);
      if (c != null) return c;
    }
    return null;
  }

  /// 보여 줄 때: ABCDE-FGHJK
  static String show(String c) => c.length == 10 ? '${c.substring(0, 5)}-${c.substring(5)}' : c;

  static String _newCode() {
    final r = Random.secure();
    return List.generate(10, (_) => _abc[r.nextInt(_abc.length)]).join();
  }

  bool get ready => sync.ready;
  DocumentReference<Map<String, dynamic>> _doc(String c) => FirebaseFirestore.instance.collection('fam').doc(c);

  /// 지금 아이의 가족 연결 코드. 없으면 서버에 새로 만든다. 서버를 못 쓰면 null(예전 링크 방식으로 대신).
  Future<String?> ensure(Kid k) async {
    if (k.fam.isNotEmpty) {
      unawaited(push());
      return k.fam;
    }
    if (!ready) return null;
    try {
      final c = _newCode();
      await _doc(c).set({
        'k': k.key, 'n': k.name, 'a': k.age, 'b': k.birth, 's': k.sex, 'f': k.who, 'p': k.firstDone ? 1 : 0,
        'at': FieldValue.serverTimestamp(), 'recs': _mine(k),
      }).timeout(const Duration(seconds: 8));
      k.fam = c;
      store.save();
      return c;
    } catch (e) {
      debugPrint('fam ensure: $e');
      return null;
    }
  }

  /// 코드로 초대 정보를 읽는다. 없거나 못 읽으면 null.
  Future<Map<String, dynamic>?> read(String code) async {
    if (!ready) return null;
    try {
      final s = await _doc(code).get().timeout(const Duration(seconds: 8));
      return s.data();
    } catch (e) {
      debugPrint('fam read: $e');
      return null;
    }
  }

  /// 이 휴대폰에서 직접 답한 기록들(받은 결과·샘플 제외)
  Map<String, dynamic> _mine(Kid k) => {
        for (final e in k.recs.entries)
          if (!e.value.recv && !e.value.sample && e.value.ans.isNotEmpty) e.key: {'x': Store.encA(e.value.ans), 'd': e.value.date, 't': e.value.t},
      };

  final _sent = <String, int>{};
  Timer? _t;

  /// 기록이 바뀌면 잠시 뒤 올린다
  void schedule() {
    if (!ready || !store.kids.any((k) => k.fam.isNotEmpty)) return;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 3), push);
  }

  /// 연결된 아이마다 이 휴대폰의 양육자 결과 중 바뀐 것을 올린다
  Future<void> push() async {
    if (!ready) return;
    for (final k in store.kids.where((k) => k.fam.isNotEmpty)) {
      final up = <Object, Object?>{};
      for (final e in _mine(k).entries) {
        final id = '${k.fam}/${e.key}', t = (e.value as Map)['t'] as int;
        if (_sent[id] == t) continue;
        up[FieldPath(['recs', e.key])] = e.value;
        _sent[id] = t;
      }
      if (up.isEmpty) continue;
      try {
        await _doc(k.fam).update(up);
      } catch (e) {
        debugPrint('fam push: $e');
        for (final f in up.keys) {
          _sent.remove('${k.fam}/${(f as FieldPath).components.last}');
        }
      }
    }
  }

  DateTime? _last;

  /// 연결된 아이마다 다른 휴대폰의 결과를 받아 합친다. 앱을 켤 때·돌아올 때·리포트를 열 때. [force] 아니면 20초에 한 번.
  /// 초대받아 처음 검사하는 사람은 자기 검사를 마칠 때까지 다른 사람 결과를 받지 않는다(서로의 답에 끌리지 않게).
  Future<void> pull({bool force = false}) async {
    if (!ready) return;
    final now = DateTime.now();
    if (!force && _last != null && now.difference(_last!).inSeconds < 20) return;
    _last = now;
    var changed = false;
    for (final k in store.kids.where((k) => k.fam.isNotEmpty)) {
      if (k.inv != null && !fullDone(k.cur.ans)) continue;
      final d = await read(k.fam);
      final recs = d?['recs'];
      if (recs is! Map) continue;
      for (final e in recs.entries) {
        final v = e.value;
        if (v is! Map || v['x'] is! String) continue;
        final rec = Rec(ans: Store.decA(v['x']), date: '${v['d'] ?? ''}', paid: true, recv: true, t: (v['t'] as num?)?.round() ?? 0);
        if (rec.ans.isEmpty) continue;
        if (store.putFamRec(k, '${e.key}', rec)) changed = true;
      }
    }
    if (changed) store.save();
    unawaited(push());
  }
}

final fam = Fam();
