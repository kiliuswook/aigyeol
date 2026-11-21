// 메일 인증 로그인과 기기 사이 동기화(Firebase). 로그인은 선택: 안 해도 이 폰에서는 다 쓸 수 있다.
// 서버 자료: users/{uid} 문서 하나 {json: 앱 기록(Store.toJson) 문자열, at: 저장 시각}. 보안 규칙은 저장소 firestore.rules.
import 'i18n.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'store.dart';

/// iOS Firebase 설정 (Firebase 콘솔 프로젝트 childmbti-wonderwheel 의 iOS 앱, 2026-11-19 등록).
/// GoogleService-Info.plist 를 Xcode 프로젝트에 넣는 대신 코드로 넘긴다. API 키는 앱에 들어가는 공개 키다(google-services.json 과 같음).
const _iosOptions = FirebaseOptions(
  apiKey: 'AIzaSyAG7qZZ5xAP_6AwjqkX3sHIMgwDIDjSHwc',
  appId: '1:799874537360:ios:dd24a7bc0ac936976d0515',
  messagingSenderId: '799874537360',
  projectId: 'childmbti-wonderwheel',
  storageBucket: 'childmbti-wonderwheel.firebasestorage.app',
  iosBundleId: 'kr.co.wonderwheel.childmbti',
);

class Sync extends ChangeNotifier {
  /// Firebase 를 쓸 수 있는 기기인지(안드로이드 앱). 웹 미리보기·테스트에서는 false.
  bool ready = false;
  User? user;
  bool busy = false;
  String? lastError;
  DateTime? lastSync;
  Timer? _t;

  bool get signedIn => user != null;
  bool get verified => user?.emailVerified ?? false;
  String get email => user?.email ?? '';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance.collection('users').doc(user!.uid);

  Future<void> init() async {
    try {
      // 안드로이드는 google-services.json, iOS 는 아래 값(Firebase 콘솔 iOS 앱 '내 아이의 MBTI iOS')으로 연다
      await Firebase.initializeApp(options: defaultTargetPlatform == TargetPlatform.iOS ? _iosOptions : null);
      _auth.setLanguageCode('ko');
      ready = true;
    } catch (_) {
      ready = false;
      return;
    }
    user = _auth.currentUser;
    store.onSaved = _schedule;
    if (verified) unawaited(pull());
    notifyListeners();
  }

  // ---------- 계정 ----------
  Future<String?> signUp(String email, String pw) => _run(() async {
    final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: pw);
    user = c.user;
    await user!.sendEmailVerification();
  });

  Future<String?> signIn(String email, String pw) => _run(() async {
    final c = await _auth.signInWithEmailAndPassword(email: email.trim(), password: pw);
    user = c.user;
    if (verified) await pull();
  });

  Future<String?> resend() => _run(() => user!.sendEmailVerification());

  /// 메일의 인증 링크를 누르고 돌아왔을 때
  Future<String?> checkVerified() => _run(() async {
    await user!.reload();
    user = _auth.currentUser;
    if (!verified) throw tr('아직 인증되지 않았어요. 메일함(스팸함 포함)에서 인증 링크를 눌러 주세요.');
    await user!.getIdToken(true); // 규칙이 인증 여부를 보도록 토큰 새로 받기
    await pull();
  });

  Future<String?> resetPw(String email) => _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() async {
    _t?.cancel();
    if (verified) await push();
    await _auth.signOut();
    user = null;
    lastSync = null;
    notifyListeners();
  }

  /// 계정 삭제: 서버의 기록과 계정을 지운다. 이 폰의 기록은 남긴다(원하면 리포트의 초기화로 지움).
  Future<String?> deleteAccount(String pw) => _run(() async {
    _t?.cancel();
    await user!.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: pw));
    await _doc.delete();
    await user!.delete();
    user = null;
    lastSync = null;
  });

  // ---------- 동기화 ----------
  /// 서버 기록을 받아 이 폰 기록과 합친 뒤 다시 올린다.
  Future<void> pull() async {
    if (!ready || !verified) return;
    try {
      final s = await _doc.get();
      final j = s.data()?['json'];
      if (j is String && j.isNotEmpty) {
        final prev = store.onSaved;
        store.onSaved = null;
        store.mergeFrom(jsonDecode(j));
        store.onSaved = prev;
      }
      await push();
    } catch (e) {
      lastError = _msg(e);
      notifyListeners();
    }
  }

  Future<void> push() async {
    if (!ready || !verified) return;
    try {
      await _doc.set({'json': jsonEncode(store.toJson()), 'at': FieldValue.serverTimestamp(), 'v': 2});
      lastSync = DateTime.now();
      lastError = null;
    } catch (e) {
      lastError = _msg(e);
    }
    notifyListeners();
  }

  void _schedule() {
    if (!verified) return;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 3), push);
  }

  Future<String?> _run(Future<void> Function() f) async {
    busy = true;
    notifyListeners();
    String? err;
    try {
      await f();
    } catch (e) {
      err = _msg(e);
    }
    busy = false;
    notifyListeners();
    return err;
  }

  static String _msg(Object e) {
    if (e is String) return e;
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => tr('메일 주소 형식이 맞지 않아요.'),
        'email-already-in-use' => tr('이미 가입한 메일이에요. 로그인해 주세요.'),
        'weak-password' => tr('비밀번호를 6자 이상으로 해 주세요.'),
        'user-not-found' || 'wrong-password' || 'invalid-credential' => tr('메일 또는 비밀번호가 맞지 않아요.'),
        'too-many-requests' => tr('시도가 너무 많아요. 잠시 뒤에 다시 해 주세요.'),
        'network-request-failed' => tr('인터넷 연결을 확인해 주세요.'),
        'requires-recent-login' => tr('보안을 위해 다시 로그인한 뒤 해 주세요.'),
        _ => tr('문제가 생겼어요({0}).', [e.code]),
      };
    }
    if (e is FirebaseException) {
      return e.code == 'unavailable' ? tr('인터넷 연결을 확인해 주세요.') : tr('동기화에 문제가 생겼어요({0}).', [e.code]);
    }
    return tr('문제가 생겼어요.');
  }
}

final sync = Sync();
