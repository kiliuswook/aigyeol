// 이 휴대폰 안의 예약 알림(서버 없음): 아침 오늘의 미션, 저녁 실천 확인, 약속·일정 미리 알려주기.
// 사용자가 오늘 탭에서 알림을 켠 때만 예약한다. 웹은 알림 없음.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'daily.dart';
import 'store.dart';

class Notify {
  final _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void>? _initing;

  /// 시험(테스트)에서 끈다
  bool off = false;

  bool get supported => !off && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() => _initing ??= _init();
  Future<void> _init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      }
      await _p.initialize(
          settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 권한은 사용자가 알림을 켤 때 묻는다(앱을 켜자마자 묻지 않게)
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ));
      _ready = true;
    } catch (_) {}
  }

  /// 알림 권한 묻기. 허락하면 true
  Future<bool> ask() async {
    await init();
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;
      }
      return await _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('daily', '오늘의 미션·약속', channelDescription: '아이에게 해 볼 오늘의 한마디와 약속·일정 알림', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
    iOS: DarwinNotificationDetails(),
  );

  /// 예약을 모두 지우고 앞으로 7일 치를 다시 건다(앱을 켤 때, 기록이 바뀔 때)
  Future<void> reschedule() async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _p.cancelAll();
      if (!daily.anyAlarm) return;
      final now = tz.TZDateTime.now(tz.local);
      var id = 1;
      Future<void> at(DateTime t, String title, String body) async {
        final when = tz.TZDateTime(tz.local, t.year, t.month, t.day, t.hour, t.minute);
        if (!when.isAfter(now) || id > 60) return; // iOS 는 예약 64개까지
        await _p.zonedSchedule(id: id++, scheduledDate: when, notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, title: title, body: body);
      }

      final k = store.kids.firstWhere((x) => x.id == store.kidId, orElse: () => store.kids.first);
      final nm = k.name.isNotEmpty ? k.name : '우리 아이';
      // 약속·일정: 하루 전, 1시간 전(시각을 안 정했으면 하루 전 오후 8시, 당일 오전 9시)
      if (daily.planAlarm) {
        for (final kid in store.kids) {
          final kn = kid.name.isNotEmpty ? kid.name : '우리 아이';
          for (final p in daily.plansOf(kid).where((p) => !p.done)) {
            final word = p.pr ? '약속' : '일정';
            if (p.tm.isNotEmpty) {
              final hm = p.tm.split(':').map(int.parse).toList();
              final t = p.date.add(Duration(hours: hm[0], minutes: hm[1]));
              await at(t.subtract(const Duration(days: 1)), '내일 ${p.tm} $kn와 ${p.t}', '$word을 미리 이야기해 주면 아이가 덜 놀라요');
              await at(t.subtract(const Duration(hours: 1)), '1시간 뒤 $kn와 ${p.t}', p.pr ? '약속을 지키면 스티커를 받아요' : '잘 다녀오세요');
            } else {
              await at(p.date.subtract(const Duration(hours: 4)), '내일은 $kn와 ${p.t}', '$word을 미리 이야기해 주면 아이가 덜 놀라요');
              await at(p.date.add(const Duration(hours: 9)), '오늘 $kn와 ${p.t}', p.pr ? '약속을 지키면 스티커를 받아요' : '잘 다녀오세요');
            }
          }
        }
      }
      // 오늘의 미션(매일 오전 9시, 미션이 바뀌는 때)과 저녁 확인, 7일 치
      for (var i = 0; i < 8; i++) {
        final d = missionDay.add(Duration(days: i));
        final m = daily.mission(k, d).$2;
        if (daily.alarm) await at(d.add(const Duration(hours: kMissionHour)), '오늘 $nm에게 해 볼 한 가지', m.t);
        if (daily.eve && !(daily.peek(k, d)?.done ?? false)) await at(d.add(const Duration(minutes: DailyStore.pm)), '오늘 미션 해 보셨나요?', '해 봤다면 스티커를 붙여 보세요');
      }
    } catch (_) {}
  }
}

final notify = Notify();
