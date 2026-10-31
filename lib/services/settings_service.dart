import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kEmptyDefault = bool.fromEnvironment('EMPTY_DEFAULT');

/// نوع آلارمی که هنگام رسیدن کلاس/امتحان پخش می‌شود.
enum AlarmSound {
  /// صدای همراه خود اپ (زنگ هشدار)
  appAlarm,

  /// زنگ اعلان پیش‌فرض گوشی
  systemAlarm,

  /// فقط لرزش، بدون صدا
  vibrateOnly,

  /// کاملاً بی‌صدا (فقط اعلان در نوار)
  silent,
}

extension AlarmSoundLabel on AlarmSound {
  String get label => switch (this) {
        AlarmSound.appAlarm => 'زنگ آلارم برنامه',
        AlarmSound.systemAlarm => 'زنگ اعلان گوشی',
        AlarmSound.vibrateOnly => 'فقط لرزش',
        AlarmSound.silent => 'بی‌صدا',
      };

  String get hint => switch (this) {
        AlarmSound.appAlarm => 'مثل ساعت‌زنگ، تا خاموشش نکنی صدا می‌ده',
        AlarmSound.systemAlarm => 'صدای اعلان پیش‌فرض اندروید',
        AlarmSound.vibrateOnly => 'گوشی می‌لرزد ولی صدا نمی‌ده',
        AlarmSound.silent => 'فقط یک اعلان بی‌صدا در نوار وضعیت',
      };
}

class AppSettings {
  final bool classReminders;
  final int minutesBefore; // ۰ تا ۱۲۰
  final bool examReminders;
  final bool askedPermission;
  final String notifGroupId; // گروهی که اعلان‌ها به برنامهٔ اون می‌رفته ('' = گروه فعال)
  final bool cancelOneHourClasses; // آیا کلاس‌های تک‌ساعته لغو/برگزار نشوند

  /// آلارم تمام‌صفحه (روی صفحهٔ قفل هم می‌آید و زنگ می‌زند)
  final bool fullScreenAlarm;

  /// نوع صدا
  final AlarmSound alarmSound;

  /// لرزش
  final bool vibrate;

  /// چند دقیقه قبل از امتحان آلارم نهایی بزند
  final int examAlarmMinutes;

  /// آلارم واقعی برای امتحان هم باشد
  final bool examFullAlarm;

  const AppSettings({
    this.classReminders = true,
    this.minutesBefore = 15,
    this.examReminders = true,
    this.askedPermission = false,
    this.notifGroupId = '',
    this.cancelOneHourClasses = !kEmptyDefault,
    this.fullScreenAlarm = true,
    this.alarmSound = AlarmSound.appAlarm,
    this.vibrate = true,
    this.examAlarmMinutes = 60,
    this.examFullAlarm = true,
  });

  AppSettings copyWith({
    bool? classReminders,
    int? minutesBefore,
    bool? examReminders,
    bool? askedPermission,
    String? notifGroupId,
    bool? cancelOneHourClasses,
    bool? fullScreenAlarm,
    AlarmSound? alarmSound,
    bool? vibrate,
    int? examAlarmMinutes,
    bool? examFullAlarm,
  }) =>
      AppSettings(
        classReminders: classReminders ?? this.classReminders,
        minutesBefore: minutesBefore ?? this.minutesBefore,
        examReminders: examReminders ?? this.examReminders,
        askedPermission: askedPermission ?? this.askedPermission,
        notifGroupId: notifGroupId ?? this.notifGroupId,
        cancelOneHourClasses: cancelOneHourClasses ?? this.cancelOneHourClasses,
        fullScreenAlarm: fullScreenAlarm ?? this.fullScreenAlarm,
        alarmSound: alarmSound ?? this.alarmSound,
        vibrate: vibrate ?? this.vibrate,
        examAlarmMinutes: examAlarmMinutes ?? this.examAlarmMinutes,
        examFullAlarm: examFullAlarm ?? this.examFullAlarm,
      );
}

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const maxMinutes = 120;
  static const minMinutes = 0;

  /// گزینه‌های آمادهٔ «چند دقیقه قبل»
  static const presets = <int>[0, 5, 10, 15, 20, 30, 45, 60, 90, 120];

  SharedPreferences? _prefs;
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    final m = p.getInt('minutesBefore') ?? 15;
    final snd = p.getInt('alarmSound') ?? AlarmSound.appAlarm.index;
    _settings = AppSettings(
      classReminders: p.getBool('classReminders') ?? true,
      minutesBefore: m.clamp(minMinutes, maxMinutes).toInt(),
      examReminders: p.getBool('examReminders') ?? true,
      askedPermission: p.getBool('askedPermission') ?? false,
      notifGroupId: p.getString('notifGroupId') ?? '',
      cancelOneHourClasses: p.getBool('cancelOneHourClasses') ?? !kEmptyDefault,
      fullScreenAlarm: p.getBool('fullScreenAlarm') ?? true,
      alarmSound: AlarmSound.values[snd.clamp(0, AlarmSound.values.length - 1)],
      vibrate: p.getBool('vibrate') ?? true,
      examAlarmMinutes: (p.getInt('examAlarmMinutes') ?? 60).clamp(0, 180).toInt(),
      examFullAlarm: p.getBool('examFullAlarm') ?? true,
    );
  }

  Future<void> update(AppSettings s) async {
    _settings = s;
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    await p.setBool('classReminders', s.classReminders);
    await p.setInt('minutesBefore', s.minutesBefore);
    await p.setBool('examReminders', s.examReminders);
    await p.setBool('askedPermission', s.askedPermission);
    await p.setString('notifGroupId', s.notifGroupId);
    await p.setBool('cancelOneHourClasses', s.cancelOneHourClasses);
    await p.setBool('fullScreenAlarm', s.fullScreenAlarm);
    await p.setInt('alarmSound', s.alarmSound.index);
    await p.setBool('vibrate', s.vibrate);
    await p.setInt('examAlarmMinutes', s.examAlarmMinutes);
    await p.setBool('examFullAlarm', s.examFullAlarm);
  }
}
