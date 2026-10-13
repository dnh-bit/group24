import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/schedule_store.dart';
import '../utils.dart';
import 'settings_service.dart';

/// همهٔ یادآوری‌ها لوکال هستن و بدون اینترنت کار می‌کنن.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();

  static const _classChannel = AndroidNotificationDetails(
    'class_reminders',
    'یادآوری کلاس‌ها',
    channelDescription: 'اعلان چند دقیقه قبل از شروع هر کلاس',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static const _examChannel = AndroidNotificationDetails(
    'exam_reminders',
    'یادآوری امتحان‌ها',
    channelDescription: 'اعلان شب قبل و یک ساعت قبل از هر امتحان',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static const _darwin = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentSound: true,
  );

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // برنامهٔ کلاس‌ها به وقت تهرانه
    tz.setLocalLocation(tz.getLocation('Asia/Tehran'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// اجازهٔ نمایش اعلان (اندروید ۱۳+ و iOS)
  Future<bool> requestPermission() async {
    if (_isAndroid) {
      return await _android?.requestNotificationsPermission() ?? true;
    }
    if (_isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return true;
  }

  /// آیا اندروید اجازهٔ آلارم دقیق داده؟ (برای اینکه اعلان دقیقاً سر وقت بیاد)
  Future<bool> canScheduleExact() async {
    if (!_isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExactAlarms() async {
    if (!_isAndroid) return;
    await _android?.requestExactAlarmsPermission();
  }

  /// اولین اجرای برنامه: یه بار اجازه می‌گیره و یادآوری‌ها رو می‌چینه
  Future<void> firstRunSetup() async {
    final svc = SettingsService.instance;
    if (!svc.settings.askedPermission) {
      await requestPermission();
      await svc.update(svc.settings.copyWith(askedPermission: true));
    }
    await reschedule();
  }

  /// همهٔ یادآوری‌ها رو از نو می‌چینه (پشت سر هم، بدون تداخل)
  Future<void> reschedule() {
    _queue = _queue.then((_) => _reschedule()).catchError((Object e) {
      debugPrint('reschedule failed: $e');
    });
    return _queue;
  }

  Future<void> _reschedule() async {
    await init();
    await _plugin.cancelAll();

    final s = SettingsService.instance.settings;
    final store = ScheduleStore.instance;
    final now = tz.TZDateTime.now(tz.local);

    final mode = await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (s.classReminders) {
      for (final ref in store.allSessions) {
        final c = ref.course;
        if (c.muted) continue;
        final se = ref.session;
        await _plugin.zonedSchedule(
          c.id * 20 + ref.index,
          '${fa(s.minutesBefore)} دقیقه تا کلاس ${c.shortName}',
          [fmtTime(se.start), if (se.room.isNotEmpty) se.room, if (c.prof.isNotEmpty) 'استاد ${c.prof}']
              .join(' · '),
          _nextWeekly(now, se.day, se.start, s.minutesBefore),
          const NotificationDetails(android: _classChannel, iOS: _darwin),
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'course:${c.id}',
        );
      }
    }

    if (s.examReminders) {
      for (final c in store.courses) {
        final e = c.exam;
        if (e == null || c.muted) continue;
        final g = e.gregorian;
        final where = e.place.isEmpty ? '' : ' · ${e.place}';

        // شب قبل، ساعت ۲۰:۰۰
        final night = tz.TZDateTime(tz.local, g.year, g.month, g.day - 1, 20);
        if (night.isAfter(now)) {
          await _plugin.zonedSchedule(
            100000 + c.id * 2,
            'فردا امتحان ${c.shortName} داری',
            '${e.weekdayName} ${e.jalaliText} · ساعت ${e.timeText}$where · موفق باشی ✦',
            night,
            const NotificationDetails(android: _examChannel, iOS: _darwin),
            androidScheduleMode: mode,
            payload: 'exam:${c.id}',
          );
        }

        // یک ساعت قبل از امتحان
        final startMin = (e.start * 60).round() - 60;
        final hourBefore = tz.TZDateTime(tz.local, g.year, g.month, g.day, startMin ~/ 60, startMin % 60);
        if (hourBefore.isAfter(now)) {
          await _plugin.zonedSchedule(
            100000 + c.id * 2 + 1,
            'یک ساعت تا امتحان ${c.shortName}',
            'ساعت ${fmtTime(e.start)}$where',
            hourBefore,
            const NotificationDetails(android: _examChannel, iOS: _darwin),
            androidScheduleMode: mode,
            payload: 'exam:${c.id}',
          );
        }
      }
    }
  }

  Future<void> showTest(int minutesBefore) async {
    await init();
    await _plugin.show(
      9999,
      '${fa(minutesBefore)} دقیقه تا کلاس بعدی',
      'این یه اعلان آزمایشیه. یادآوری‌ها همین شکلی میان ✦',
      const NotificationDetails(android: _classChannel, iOS: _darwin),
    );
  }

  Future<int> pendingCount() async {
    await init();
    return (await _plugin.pendingNotificationRequests()).length;
  }

  /// نزدیک‌ترین زمانِ آیندهٔ این جلسه (منهای چند دقیقه)
  tz.TZDateTime _nextWeekly(tz.TZDateTime now, int dayIdx, double startHour, int minutesBefore) {
    final totalMin = (startHour * 60).round() - minutesBefore;
    var dayShift = 0;
    var m = totalMin;
    if (m < 0) {
      // مثلاً کلاس ساعت ۰۰:۱۰ → اعلان روز قبل
      m += 24 * 60;
      dayShift = -1;
    }
    final targetDay = (dayIdx + dayShift + 7) % 7;
    final hh = m ~/ 60;
    final mm = m % 60;
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hh, mm);
    var guard = 0;
    while ((dayIndexOf(t) != targetDay || !t.isAfter(now)) && guard < 14) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hh, mm);
      guard++;
    }
    return t;
  }
}
