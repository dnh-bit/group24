import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/schedule_store.dart';
import '../utils.dart';
import 'settings_service.dart';

/// همهٔ یادآوری‌ها لوکال هستن و بدون اینترنت کار می‌کنن.
///
/// دو حالت داریم:
///  • یادآوری ساده (اعلان معمولی، یک بار صدا می‌ده)
///  • آلارم (اعلان تمام‌صفحه + زنگ + دکمهٔ خاموش/تعویق)
///
/// هر درس و هر جلسه می‌تونه اعلان خودش رو خاموش کنه، و هر درس می‌تونه
/// دقیقهٔ آلارم مخصوص خودش رو داشته باشه.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// ضربهٔ کاربر روی اعلان — از main تنظیم می‌شه تا مسیر یادگیری باز بشه.
  static void Function(String payload)? onNotificationTap;

  /// دکمهٔ «۵ دقیقهٔ دیگر» روی اعلان زده شد.
  static void Function(String payload, int minutes)? onSnooze;

  /// اگر کاربر قبل از آماده شدن navigator روی اعلان بزنه، اینجا نگه داشته می‌شه.
  static String? pendingTap;

  /// اگر «۵ دقیقهٔ دیگر» قبل از آماده شدن سرویس زده شد.
  static String? pendingSnooze;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();

  // ── شناسهٔ کانال‌ها ──
  // اندروید اجازهٔ تغییر صدا/لرزش کانالِ ساخته‌شده را نمی‌دهد، پس برای هر
  // ترکیب «آلارم / بی‌صدا / با لرزش» یک کانال جدا داریم.
  // اندروید صدا و لرزش کانال را بعد از ساخت عوض نمی‌کند، پس هر ترکیب
  // «صدا × لرزش» کانال خودش را دارد و همه از اول ساخته می‌شوند.
  static const _chAlarm = 'class_alarm_v2'; // زنگ برنامه، بدون لرزش
  static const _chAlarmVibrate = 'class_alarm_vibrate_v2'; // زنگ برنامه + لرزش
  static const _chDefaultSound = 'class_default_sound_v2'; // زنگ گوشی، بدون لرزش
  static const _chDefaultVibrate = 'class_default_vibrate_v2'; // زنگ گوشی + لرزش
  static const _chVibrateOnly = 'class_vibrate_only_v2'; // فقط لرزش
  static const _chQuiet = 'class_quiet_v2';
  static const _chExamQuiet = 'exam_quiet_v2';

  static const _actions = <AndroidNotificationAction>[
    AndroidNotificationAction('snooze', '۵ دقیقهٔ دیگر', showsUserInterface: false),
    AndroidNotificationAction('dismiss', 'خاموش', showsUserInterface: false),
  ];

  static const _darwin = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleTap,
      onDidReceiveBackgroundNotificationResponse: backgroundTap,
    );
    await _createChannels();
    _ready = true;

    // اگر «۵ دقیقهٔ دیگر» قبل از آماده شدن سرویس زده شده بود
    final ps = pendingSnooze;
    if (ps != null) {
      pendingSnooze = null;
      await snooze(ps, 5);
    }
  }

  /// کانال‌ها یک بار ساخته می‌شن؛ اندروید ۸+ صدا و لرزش را از کانال می‌گیرد.
  Future<void> _createChannels() async {
    final a = _android;
    if (a == null) return;
    const alarmSound = RawResourceAndroidNotificationSound('alarm');
    final pattern = Int64List.fromList(<int>[0, 800, 600, 800]);
    await a.createNotificationChannel(AndroidNotificationChannel(
      _chAlarm,
      'آلارم کلاس‌ها',
      description: 'آلارم تمام‌صفحهٔ قبل از شروع کلاس، با صدا',
      importance: Importance.max,
      playSound: true,
      sound: alarmSound,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      _chAlarmVibrate,
      'آلارم کلاس‌ها (با لرزش)',
      description: 'آلارم تمام‌صفحهٔ قبل از شروع کلاس، با صدا و لرزش',
      importance: Importance.max,
      playSound: true,
      sound: alarmSound,
      enableVibration: true,
      vibrationPattern: pattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(const AndroidNotificationChannel(
      _chDefaultSound,
      'آلارم با زنگ گوشی',
      description: 'آلارم کلاس با صدای اعلان پیش‌فرض گوشی',
      importance: Importance.max,
      playSound: true,
      enableVibration: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      _chDefaultVibrate,
      'آلارم با زنگ گوشی (و لرزش)',
      description: 'آلارم کلاس با صدای اعلان پیش‌فرض گوشی و لرزش',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: pattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      _chVibrateOnly,
      'آلارم فقط لرزش',
      description: 'آلارم کلاس بدون صدا، فقط لرزش',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      vibrationPattern: pattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    await a.createNotificationChannel(const AndroidNotificationChannel(
      _chQuiet,
      'یادآوری بی‌صدا',
      description: 'یادآوری کلاس بدون صدا و آلارم',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    ));
    await a.createNotificationChannel(const AndroidNotificationChannel(
      _chExamQuiet,
      'یادآوری امتحان بی‌صدا',
      description: 'یادآوری امتحان بدون آلارم',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    ));
  }

  // ── بازه‌های شناسهٔ اعلان (نباید هیچ‌وقت روی هم بیفتند) ──
  //   کلاس:   1 .. 100_000   (هر درس ۴۰ شناسه، حداکثر ۲۵۰۰ درس)
  //   امتحان: 200_000 .. 204_999
  //   تعویق:  500_000 .. 502_499
  static const _maxCourses = 2500;

  /// شناسهٔ اعلان یک جلسه؛ هر درس ۴۰ جا دارد و بیشتر از ۳۹ جلسه در یک درس
  /// واقع‌بینانه نیست (بیشتر از آن نادیده گرفته می‌شود تا شناسه‌ها قاطی نشوند).
  static int _sessionId(int courseSlot, int sessionIndex) {
    final idx = sessionIndex.clamp(0, 39).toInt();
    return courseSlot * 40 + idx + 1;
  }

  static int _examId(int courseSlot, int kind) => 200000 + courseSlot * 2 + kind;

  /// آیا این اعلان باید به‌شکل آلارم (تمام‌صفحه) بیاید؟
  bool _alarmWanted({required bool isExam}) {
    final s = SettingsService.instance.settings;
    if (!s.fullScreenAlarm) return false;
    if (s.alarmSound == AlarmSound.silent) return false;
    if (isExam && !s.examFullAlarm) return false;
    return true;
  }

  NotificationDetails _details({required bool isAlarm, required bool isExam}) {
    final s = SettingsService.instance.settings;
    final String channelId;
    if (!isAlarm) {
      channelId = isExam ? _chExamQuiet : _chQuiet;
    } else {
      channelId = switch (s.alarmSound) {
        AlarmSound.vibrateOnly => _chVibrateOnly,
        AlarmSound.systemAlarm => s.vibrate ? _chDefaultVibrate : _chDefaultSound,
        _ => s.vibrate ? _chAlarmVibrate : _chAlarm,
      };
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isAlarm ? 'آلارم' : 'یادآوری',
        channelDescription: isAlarm ? 'آلارم کلاس و امتحان' : 'یادآوری کلاس',
        importance: isAlarm ? Importance.max : Importance.high,
        priority: isAlarm ? Priority.max : Priority.high,
        category: isAlarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        fullScreenIntent: isAlarm,
        autoCancel: true,
        // آلارمی که ۵ دقیقه بی‌جواب بماند خودش کنار می‌رود تا نوار اشغال نشود.
        timeoutAfter: isAlarm ? 5 * 60 * 1000 : null,
        actions: isAlarm ? _actions : null,
        visibility: NotificationVisibility.public,
      ),
      iOS: _darwin,
    );
  }

  static void _handleTap(NotificationResponse r) {
    final actionId = r.actionId;
    final p = r.payload ?? '';

    if (actionId == 'snooze') {
      final f = onSnooze;
      if (f != null) {
        f(p, 5);
      } else {
        pendingSnooze = p;
      }
      return;
    }
    if (actionId == 'dismiss') return;

    final f = onNotificationTap;
    if (f != null) {
      f(p);
    } else if (p.startsWith('course:') || p.startsWith('exam:')) {
      pendingTap = p;
    }
  }

  @pragma('vm:entry-point')
  static void backgroundTap(NotificationResponse r) => _handleTap(r);

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

  /// شمارهٔ SDK اندروید (۳۴ = اندروید ۱۴)؛ اگر نشد ۰.
  static int get androidSdk {
    if (kIsWeb || !Platform.isAndroid) return 0;
    final v = Platform.operatingSystemVersion;
    final m = RegExp(r'SDK\s+(\d+)').firstMatch(v);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  /// اندروید ۱۴+ برای آلارم تمام‌صفحه اجازهٔ جدا می‌خواهد.
  static bool get needsFullScreenPermission => androidSdk >= 34;

  /// درخواست اجازهٔ «اعلان تمام‌صفحه». نتیجهٔ واقعی را برمی‌گرداند.
  Future<bool> requestFullScreen() async {
    if (!_isAndroid) return true;
    return await _android?.requestFullScreenIntentPermission() ?? true;
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

  /// دقیقهٔ آلارم مؤثر برای یک درس: مقدار اختصاصی درس، وگرنه تنظیم کلی.
  static int minutesFor(Course c) {
    final v = c.alarmMinutes ?? SettingsService.instance.settings.minutesBefore;
    return v.clamp(0, SettingsService.maxMinutes).toInt();
  }

  /// آیا این درس اصلاً اعلان بگیرد؟
  static bool courseEnabled(Course c) => !c.muted;

  /// آیا این جلسه اعلان بگیرد؟ (درس روشن + جلسه روشن + تک‌ساعته نباشد)
  bool sessionAlarmEnabled(Course c, Session se) {
    final s = SettingsService.instance.settings;
    if (!courseEnabled(c)) return false;
    if (se.alarmOff) return false;
    if (s.cancelOneHourClasses && se.isOneHour) return false;
    return true;
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

    // فقط برنامهٔ گروهی که کاربر برای اعلان انتخاب کرده (نه همهٔ گروه‌ها)
    final notifGroup = store.groupForNotifications();
    final groupSessions = store.sessionsOfGroup(notifGroup);

    if (s.classReminders) {
      // شمارهٔ جایگاه درس در همین گروه (نه id فایل) → شناسه‌های اعلان یکتا
      final slot = <int, int>{};
      for (var i = 0; i < notifGroup.courses.length && i < _maxCourses; i++) {
        slot[notifGroup.courses[i].id] = i;
      }

      for (final ref in groupSessions) {
        final c = ref.course;
        final se = ref.session;
        if (!sessionAlarmEnabled(c, se)) continue;
        final ci = slot[c.id];
        if (ci == null) continue;

        final mins = minutesFor(c);
        final isAlarm = _alarmWanted(isExam: false);

        await _plugin.zonedSchedule(
          _sessionId(ci, ref.index),
          mins == 0
              ? 'کلاس ${c.shortName} همین حالا شروع می‌شه'
              : '${fa(mins)} دقیقه تا کلاس ${c.shortName}',
          [fmtTime(se.start), if (se.room.isNotEmpty) se.room, if (c.prof.isNotEmpty) 'استاد ${c.prof}']
              .join(' · '),
          _nextWeekly(now, se.day, se.start, mins),
          _details(isAlarm: isAlarm, isExam: false),
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'course:${c.id}',
        );
      }
    }

    if (s.examReminders) {
      for (var ci = 0; ci < notifGroup.courses.length && ci < _maxCourses; ci++) {
        final c = notifGroup.courses[ci];
        final e = c.exam;
        if (e == null || c.muted) continue;
        final g = e.gregorian;
        final where = e.place.isEmpty ? '' : ' · ${e.place}';
        final alarmMins = s.examAlarmMinutes.clamp(0, 180).toInt();

        // شب قبل، ساعت ۲۰:۰۰ (یادآوری ساده)
        final night = tz.TZDateTime(tz.local, g.year, g.month, g.day - 1, 20);
        if (night.isAfter(now)) {
          await _plugin.zonedSchedule(
            _examId(ci, 0),
            'فردا امتحان ${c.shortName} داری',
            '${e.weekdayName} ${e.jalaliText} · ساعت ${e.timeText}$where · موفق باشی ✦',
            night,
            _details(isAlarm: false, isExam: true),
            androidScheduleMode: mode,
            payload: 'exam:${c.id}',
          );
        }

        // آلارم نهایی N دقیقه قبل از امتحان
        final startMin = (e.start * 60).round() - alarmMins;
        var dayShift = 0;
        var m = startMin;
        while (m < 0) {
          m += 24 * 60;
          dayShift -= 1;
        }
        final alarmAt =
            tz.TZDateTime(tz.local, g.year, g.month, g.day + dayShift, m ~/ 60, m % 60);
        if (alarmAt.isAfter(now)) {
          await _plugin.zonedSchedule(
            _examId(ci, 1),
            alarmMins == 0
                ? 'الان امتحان ${c.shortName} شروع می‌شه'
                : '${fa(alarmMins)} دقیقه تا امتحان ${c.shortName}',
            'ساعت ${fmtTime(e.start)}$where · موفق باشی ✦',
            alarmAt,
            _details(isAlarm: _alarmWanted(isExam: true), isExam: true),
            androidScheduleMode: mode,
            payload: 'exam:${c.id}',
          );
        }
      }
    }
  }

  /// «۵ دقیقهٔ دیگر»: یک آلارم تک‌باره از الان به تعویق می‌اندازد.
  Future<void> snooze(String payload, int minutes) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    final at = now.add(Duration(minutes: minutes));
    final isExam = payload.startsWith('exam:');
    final id = int.tryParse(payload.split(':').last) ?? 0;
    final c = _findCourse(id);

    final String title;
    final String body;
    if (isExam) {
      final e = c?.exam;
      title = '${fa(minutes)} دقیقهٔ دیگر امتحان ${c?.shortName ?? ''}'.trim();
      body = e == null ? 'موفق باشی ✦' : 'ساعت ${fmtTime(e.start)} · موفق باشی ✦';
    } else {
      title = '${fa(minutes)} دقیقهٔ دیگر کلاس ${c?.shortName ?? ''}'.trim();
      body = 'یادت نره ✦';
    }

    // شناسهٔ تعویق بر اساس جایگاه درس در گروه است (نه id فایل) تا دو درس
    // مختلف با id بزرگ، تعویق همدیگر را پاک نکنند.
    final slot = _slotOf(id);
    await _plugin.zonedSchedule(
      500000 + slot,
      title,
      body,
      at,
      _details(isAlarm: _alarmWanted(isExam: isExam), isExam: isExam),
      androidScheduleMode: await canScheduleExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// جایگاه درس در گروه اعلان‌ها (۰..۲۴۹۹)؛ اگر پیدا نشد ۲۴۹۹.
  static int _slotOf(int courseId) {
    final courses = ScheduleStore.instance.groupForNotifications().courses;
    for (var i = 0; i < courses.length && i < _maxCourses; i++) {
      if (courses[i].id == courseId) return i;
    }
    return _maxCourses - 1;
  }

  Course? _findCourse(int id) {
    for (final c in ScheduleStore.instance.groupForNotifications().courses) {
      if (c.id == id) return c;
    }
    for (final g in ScheduleStore.instance.groups) {
      for (final c in g.courses) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// اعلان آزمایشی — دقیقاً همان شکلی که در واقعیت می‌آید.
  Future<void> showTest(int minutesBefore, {bool asAlarm = true}) async {
    await init();
    final isAlarm = asAlarm && _alarmWanted(isExam: false);
    await _plugin.show(
      9999,
      minutesBefore == 0
          ? 'کلاس بعدی همین حالا شروع می‌شه'
          : '${fa(minutesBefore)} دقیقه تا کلاس بعدی',
      isAlarm
          ? 'این یک آلارم آزمایشیه — با دکمهٔ «خاموش» یا «۵ دقیقهٔ دیگر» ببندش ✦'
          : 'این یک اعلان آزمایشیه. یادآوری‌ها همین شکلی میان ✦',
      _details(isAlarm: isAlarm, isExam: false),
    );
  }

  Future<int> pendingCount() async {
    await init();
    return (await _plugin.pendingNotificationRequests()).length;
  }

  /// نزدیک‌ترین زمانِ آیندهٔ این جلسه (منهای چند دقیقه). هر دقیقه از ۰ تا ۱۲۰ پشتیبانی می‌شود.
  tz.TZDateTime _nextWeekly(tz.TZDateTime now, int dayIdx, double startHour, int minutesBefore) {
    final totalMin = (startHour * 60).round() - minutesBefore;
    var dayShift = 0;
    var m = totalMin;
    while (m < 0) {
      // مثلاً آلارم ۳۰ دقیقه قبل برای کلاس ساعت ۰۰:۱۰ → روز قبل
      m += 24 * 60;
      dayShift -= 1;
    }
    final targetDay = (dayIdx + dayShift + 7) % 7;
    final hh = m ~/ 60;
    final mm = m % 60;
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hh, mm);
    var guard = 0;
    while ((dayIndexOf(t) != targetDay || !t.isAfter(now)) && guard < 21) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hh, mm);
      guard++;
    }
    return t;
  }
}
