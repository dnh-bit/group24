import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';
import 'package:course_plan/services/settings_service.dart';

/// قواعد آلارم نباید بی‌سروصدا برگردند: هر تغییر در تنظیمات یا مدل‌ها
/// باید این تست‌ها را پاس کند.
void main() {
  group('تنظیمات آلارم', () {
    test('پیش‌فرض‌ها: آلارم تمام‌صفحه روشن، زنگ برنامه، لرزش روشن', () {
      const s = AppSettings();
      expect(s.fullScreenAlarm, isTrue);
      expect(s.alarmSound, AlarmSound.appAlarm);
      expect(s.vibrate, isTrue);
      expect(s.examAlarmMinutes, 60);
      expect(s.examFullAlarm, isTrue);
    });

    test('copyWith هیچ فیلد آلارمی را جا نمی‌اندازد', () {
      const s = AppSettings();
      final t = s.copyWith(
        alarmSound: AlarmSound.vibrateOnly,
        fullScreenAlarm: false,
        vibrate: false,
        examAlarmMinutes: 30,
        examFullAlarm: false,
      );
      expect(t.alarmSound, AlarmSound.vibrateOnly);
      expect(t.fullScreenAlarm, isFalse);
      expect(t.vibrate, isFalse);
      expect(t.examAlarmMinutes, 30);
      expect(t.examFullAlarm, isFalse);
      // فیلدهای قدیمی دست‌نخورده
      expect(t.classReminders, s.classReminders);
      expect(t.minutesBefore, s.minutesBefore);
      expect(t.cancelOneHourClasses, s.cancelOneHourClasses);
    });

    test('بازهٔ دقیقهٔ آلارم ۰ تا ۱۲۰ است (۰ = سرِ وقت)', () {
      expect(SettingsService.minMinutes, 0);
      expect(SettingsService.maxMinutes, 120);
      expect(SettingsService.presets.first, 0);
      expect(SettingsService.presets.contains(30), isTrue);
      expect(SettingsService.presets.contains(60), isTrue);
      expect(SettingsService.presets.contains(90), isTrue);
      expect(SettingsService.presets.contains(120), isTrue);
    });

    test('هر نوع صدا برچسب فارسی دارد', () {
      for (final v in AlarmSound.values) {
        expect(v.label.trim(), isNotEmpty);
        expect(v.hint.trim(), isNotEmpty);
      }
    });
  });

  group('حالت اعلان هر درس (آلارم / اعلان / خاموش)', () {
    test('پیش‌فرض هر درس «آلارم» است', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0]);
      expect(c.alert, CourseAlert.alarm);
      expect(c.alertsOn, isTrue);
    });

    test('«فقط اعلان» روشن است ولی آلارم نمی‌زند', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0], alert: CourseAlert.notice);
      expect(c.alertsOn, isTrue);
      expect(c.alert, CourseAlert.notice);
    });

    test('«خاموش» هیچ اعلانی نمی‌گیرد', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0], alert: CourseAlert.off);
      expect(c.alertsOn, isFalse);
    });

    test('حالت در JSON ذخیره و بازگردانی می‌شود', () {
      for (final a in CourseAlert.values) {
        final c = Course(id: 1, name: 'x', colorValue: kCoursePalette[0], alert: a);
        final back = Course.fromJson(c.toJson());
        expect(back.alert, a, reason: 'حالت ${a.name} گم شد');
      }
    });

    test('حالت از فایل چت‌بات با کلمات فارسی/انگلیسی خوانده می‌شود', () {
      Map<String, dynamic> base(String v) => {'id': 1, 'name': 'x', 'color': 0, 'alert': v};
      expect(Course.fromJson(base('alarm')).alert, CourseAlert.alarm);
      expect(Course.fromJson(base('آلارم')).alert, CourseAlert.alarm);
      expect(Course.fromJson(base('زنگ')).alert, CourseAlert.alarm);
      expect(Course.fromJson(base('notice')).alert, CourseAlert.notice);
      expect(Course.fromJson(base('اعلان')).alert, CourseAlert.notice);
      expect(Course.fromJson(base('notification')).alert, CourseAlert.notice);
      expect(Course.fromJson(base('off')).alert, CourseAlert.off);
      expect(Course.fromJson(base('خاموش')).alert, CourseAlert.off);
      expect(Course.fromJson(base('silent')).alert, CourseAlert.off);
    });

    test('فایل قدیمی که فقط muted دارد → خاموش', () {
      final c = Course.fromJson({'id': 1, 'name': 'x', 'color': 0, 'muted': true});
      expect(c.alert, CourseAlert.off);
      expect(c.alertsOn, isFalse);
      // و فایل بدون هیچ کلیدی → آلارم
      expect(Course.fromJson({'id': 2, 'name': 'y', 'color': 0}).alert, CourseAlert.alarm);
    });

    test('چرخهٔ کلیک: آلارم → اعلان → خاموش → آلارم', () {
      expect(CourseAlert.alarm.next, CourseAlert.notice);
      expect(CourseAlert.notice.next, CourseAlert.off);
      expect(CourseAlert.off.next, CourseAlert.alarm);
    });

    test('هر حالت برچسب و توضیح فارسی دارد', () {
      for (final a in CourseAlert.values) {
        expect(a.label.trim(), isNotEmpty);
        expect(a.hint.trim(), isNotEmpty);
      }
    });

    test('copyWith حالت را حفظ می‌کند', () {
      final c = Course(id: 1, name: 'x', colorValue: kCoursePalette[0], alert: CourseAlert.notice);
      expect(c.copyWith(units: 3).alert, CourseAlert.notice);
      expect(c.copyWith(sessions: const []).alert, CourseAlert.notice);
      expect(c.copyWith(alert: CourseAlert.off).alert, CourseAlert.off);
      expect(c.copyWith(alert: CourseAlert.off).alert.next, CourseAlert.alarm);
    });
  });

  group('کلید اعلان هر جلسه', () {
    test('پیش‌فرض: اعلان جلسه روشن است', () {
      const s = Session(day: 0, start: 8, end: 10);
      expect(s.alarmOff, isFalse);
    });

    test('alarmOff در copyWith حفظ/تغییر می‌کند', () {
      const s = Session(day: 0, start: 8, end: 10);
      final off = s.copyWith(alarmOff: true);
      expect(off.alarmOff, isTrue);
      expect(off.day, 0);
      expect(off.start, 8);
      expect(off.end, 10);
      // بقیهٔ copyWith هم نباید alarmOff را صفر کند
      expect(off.copyWith(room: 'کلاس ۲۰۴').alarmOff, isTrue);
      expect(off.copyWith(start: 9).alarmOff, isTrue);
    });

    test('alarmOff در JSON ذخیره و بازگردانی می‌شود', () {
      const s = Session(day: 2, start: 10, end: 12, room: '۲۰۴', type: 'عملی', alarmOff: true);
      final j = s.toJson();
      expect(j['alarmOff'], isTrue);
      final back = Session.fromJson(j);
      expect(back.alarmOff, isTrue);
      expect(back.day, 2);
      expect(back.room, '۲۰۴');
    });

    test('جلسهٔ روشن کلید alarmOff را در JSON نمی‌نویسد (حجم کمتر)', () {
      const s = Session(day: 0, start: 8, end: 10);
      expect(s.toJson().containsKey('alarmOff'), isFalse);
    });

    test('alarmOff از کلیدهای فارسی/متن هم خوانده می‌شود', () {
      expect(Session.fromJson({'day': 0, 'start': 8, 'end': 10, 'بی‌صدا': true}).alarmOff, isTrue);
      expect(Session.fromJson({'day': 0, 'start': 8, 'end': 10, 'silent': 'بله'}).alarmOff, isTrue);
      expect(Session.fromJson({'day': 0, 'start': 8, 'end': 10, 'silent': 1}).alarmOff, isTrue);
      expect(Session.fromJson({'day': 0, 'start': 8, 'end': 10, 'silent': 'خیر'}).alarmOff, isFalse);
    });
  });

  group('دقیقهٔ آلارم هر درس', () {
    test('پیش‌فرض درس: از تنظیم کلی استفاده می‌کند', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0]);
      expect(c.alarmMinutes, isNull);
    });

    test('دقیقهٔ اختصاصی درس ذخیره و بازگردانی می‌شود', () {
      final c = Course(id: 1, name: 'کارورزی ۳', colorValue: kCoursePalette[0], alarmMinutes: 45);
      final back = Course.fromJson(c.toJson());
      expect(back.alarmMinutes, 45);
    });

    test('clearAlarmMinutes درس را به «مثل بقیه» برمی‌گرداند', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0], alarmMinutes: 30);
      expect(c.copyWith(clearAlarmMinutes: true).alarmMinutes, isNull);
      // ولی بقیهٔ فیلدها سالماند
      expect(c.copyWith(clearAlarmMinutes: true).name, 'ریاضی');
    });

    test('دقیقهٔ آلارم از فایل چت‌بات هم خوانده می‌شود', () {
      final c = Course.fromJson({
        'id': 1,
        'name': 'ریاضی',
        'color': 0,
        'alarmMinutes': 30,
      });
      expect(c.alarmMinutes, 30);
      final c2 = Course.fromJson({'id': 2, 'name': 'فیزیک', 'color': 1, 'alarm': '۲۰'});
      expect(c2.alarmMinutes, 20);
    });

    test('دقیقهٔ منفی/بزرگ‌تر از ۱۸۰ به بازهٔ مجاز بریده می‌شود', () {
      final a = Course.fromJson({'id': 1, 'name': 'x', 'color': 0, 'alarmMinutes': 999});
      expect(a.alarmMinutes, 180);
      final b = Course.fromJson({'id': 2, 'name': 'y', 'color': 0, 'alarmMinutes': -5});
      expect(b.alarmMinutes, isNull);
    });
  });

  group('ثبت تغییرات درس', () {
    test('updateCourse با groupId روی گروه درست اثر می‌گذارد', () async {
      final store = ScheduleStore.instance;
      final originalId = store.activeGroupId;
      // گروه دوم با کپی درس‌ها → درس‌ها همان id گروه اول را دارند (حالت واقعی)
      final g = await store.addGroup(name: 'گروه تست آلارم', copyCoursesFromActive: true);
      final course = g.courses.first;
      final updated = course.copyWith(alert: CourseAlert.notice, alarmMinutes: 20);

      // گروه فعال را عوض کن تا مطمئن شویم updateCourse به گروه فعال وابسته نیست
      await store.selectGroup(originalId);
      final ok = await store.updateCourse(updated, groupId: g.id);
      expect(ok, isTrue);

      final target = store.groups.firstWhere((x) => x.id == g.id);
      final found = target.courses.firstWhere((c) => c.id == course.id);
      expect(found.alert, CourseAlert.notice);
      expect(found.alarmMinutes, 20);

      // گروه دیگر نباید دست خورده باشد (باگ id مشترک)
      final other = store.groups.firstWhere((x) => x.id == originalId);
      final same = other.courses.where((c) => c.id == course.id);
      for (final c in same) {
        expect(c.alert, CourseAlert.alarm, reason: 'گروه دیگر بی‌دلیل خاموش شد');
      }

      await store.removeGroup(g.id);
      await store.selectGroup(originalId);
    });

    test('updateCourse بدون groupId درسِ گروه فعال را عوض می‌کند', () async {
      final store = ScheduleStore.instance;
      final active = store.activeGroup;
      if (active.courses.isEmpty) return;
      final c = active.courses.first;
      await store.updateCourse(c.copyWith(alarmMinutes: 15));
      final back = store.activeGroup.courses.firstWhere((x) => x.id == c.id);
      expect(back.alarmMinutes, 15);
      await store.updateCourse(c.copyWith(clearAlarmMinutes: true));
      expect(store.activeGroup.courses.firstWhere((x) => x.id == c.id).alarmMinutes, isNull);
    });

    test('updateCourse برای درس ناموجود false برمی‌گرداند', () async {
      final ok = await ScheduleStore.instance.updateCourse(
        Course(id: 999999, name: 'ناموجود', colorValue: kCoursePalette[0]),
      );
      expect(ok, isFalse);
    });
  });

  group('فیکسچر واقعی چت‌بات با آلارم', () {
    test('ایمپورت فایل دوست، همهٔ درس‌ها را با اعلان روشن می‌آورد', () {
      final text = File('test/fixtures/friend_plan.json').readAsStringSync();
      final r = ScheduleStore.instance.parseAnyToGroups(text);
      for (final c in r.groups.first.courses) {
        expect(c.alertsOn, isTrue, reason: 'درس «${c.name}» بی‌دلیل خاموش آمده');
        expect(c.alert, CourseAlert.alarm, reason: 'درس «${c.name}» باید آلارم بگیرد');
        for (final s in c.sessions) {
          expect(s.alarmOff, isFalse, reason: 'جلسهٔ «${c.name}» بی‌دلیل بی‌اعلان آمده');
        }
      }
    });
  });
}
