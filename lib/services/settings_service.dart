import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kEmptyDefault = bool.fromEnvironment('EMPTY_DEFAULT');

class AppSettings {
  final bool classReminders;
  final int minutesBefore; // ۱ تا ۱۵
  final bool examReminders;
  final bool askedPermission;
  final String notifGroupId; // گروهی که اعلان‌ها به برنامهٔ اون می‌رفته ('' = گروه فعال)
  final bool cancelOneHourClasses; // آیا کلاس‌های تک‌ساعته لغو/برگزار نشوند

  const AppSettings({
    this.classReminders = true,
    this.minutesBefore = 15,
    this.examReminders = true,
    this.askedPermission = false,
    this.notifGroupId = '',
    this.cancelOneHourClasses = !kEmptyDefault,
  });

  AppSettings copyWith({
    bool? classReminders,
    int? minutesBefore,
    bool? examReminders,
    bool? askedPermission,
    String? notifGroupId,
    bool? cancelOneHourClasses,
  }) =>
      AppSettings(
        classReminders: classReminders ?? this.classReminders,
        minutesBefore: minutesBefore ?? this.minutesBefore,
        examReminders: examReminders ?? this.examReminders,
        askedPermission: askedPermission ?? this.askedPermission,
        notifGroupId: notifGroupId ?? this.notifGroupId,
        cancelOneHourClasses: cancelOneHourClasses ?? this.cancelOneHourClasses,
      );
}

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const maxMinutes = 15;
  static const minMinutes = 1;

  SharedPreferences? _prefs;
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    final m = p.getInt('minutesBefore') ?? 15;
    _settings = AppSettings(
      classReminders: p.getBool('classReminders') ?? true,
      minutesBefore: m.clamp(minMinutes, maxMinutes),
      examReminders: p.getBool('examReminders') ?? true,
      askedPermission: p.getBool('askedPermission') ?? false,
      notifGroupId: p.getString('notifGroupId') ?? '',
      cancelOneHourClasses: p.getBool('cancelOneHourClasses') ?? !kEmptyDefault,
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
  }
}
