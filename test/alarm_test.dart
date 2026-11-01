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

  group('پیش‌فرض اعلان درس‌ها', () {
    test('درس تنظیم‌نشده از پیش‌فرض تنظیمات پیروی می‌کند', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0]);
      expect(c.alertExplicit, isFalse, reason: 'درس تازه نباید «انتخاب‌شده» باشد');
    });

    test('انتخاب دستی، درس را explicit می‌کند', () {
      final c = Course(id: 1, name: 'ریاضی', colorValue: kCoursePalette[0]);
      expect(c.copyWith(alert: CourseAlert.notice).alertExplicit, isTrue);
      // و بعد از آن، copyWithهای دیگر آن را از دست نمی‌دهند
      expect(c.copyWith(alert: CourseAlert.notice).copyWith(units: 3).alertExplicit, isTrue);
    });

    test('درس دست‌نخورده بعد از ذخیره/بازخوانی هم دست‌نخورده می‌ماند', () {
      // باگ واقعی: toJson همیشه alert را می‌نوشت، پس هر درس بعد از یک بار
      // ذخیره «انتخاب‌شده» می‌شد و پیش‌فرض تنظیمات دیگر اثر نداشت.
      final auto = Course(id: 1, name: 'x', colorValue: kCoursePalette[0]);
      final j = auto.toJson();
      expect(j.containsKey('alert'), isFalse,
          reason: 'برای درس تنظیم‌نشده نباید alert نوشته شود');
      final back = Course.fromJson(j);
      expect(back.alertExplicit, isFalse);
      // و پیش‌فرض تنظیمات روی آن اثر می‌گذارد
      expect(j.containsKey('alertExplicit'), isFalse);
    });

    test('درس دستی بعد از ذخیره/بازخوانی «انتخاب‌شده» می‌ماند', () {
      final manual = Course(
        id: 2,
        name: 'y',
        colorValue: kCoursePalette[0],
        alert: CourseAlert.notice,
        alertExplicit: true,
      );
      final back = Course.fromJson(manual.toJson());
      expect(back.alertExplicit, isTrue);
      expect(back.alert, CourseAlert.notice);
    });

    test('alertExplicit در JSON ذخیره و بازگردانی می‌شود', () {
      final explicit = Course(id: 1, name: 'x', colorValue: kCoursePalette[0], alert: CourseAlert.notice);
      expect(Course.fromJson(explicit.toJson()).alertExplicit, isTrue);
      final auto = Course(id: 2, name: 'y', colorValue: kCoursePalette[0]);
      expect(Course.fromJson(auto.toJson()).alertExplicit, isFalse);
    });

    test('فایل چت‌بات که alert دارد → explicit', () {
      final c = Course.fromJson({'id': 1, 'name': 'x', 'color': 0, 'alert': 'notice'});
      expect(c.alertExplicit, isTrue);
      expect(c.alert, CourseAlert.notice);
      // فایل بدون کلید alert → از پیش‌فرض
      final d = Course.fromJson({'id': 2, 'name': 'y', 'color': 0});
      expect(d.alertExplicit, isFalse);
    });

    test('پیش‌فرض تنظیمات: آلارم، و onboarding ندیده', () {
      const s = AppSettings();
      expect(s.defaultAlert, CourseAlert.alarm);
      expect(s.onboarded, isFalse);
    });

    test('copyWith پیش‌فرض و onboarded را حفظ می‌کند', () {
      const s = AppSettings();
      final t = s.copyWith(defaultAlert: CourseAlert.notice, onboarded: true);
      expect(t.defaultAlert, CourseAlert.notice);
      expect(t.onboarded, isTrue);
      expect(t.copyWith(minutesBefore: 20).defaultAlert, CourseAlert.notice);
      expect(t.copyWith(minutesBefore: 20).onboarded, isTrue);
    });
  });

  group('کلید اعلان هر جلسه', () {
    test('جلسهٔ دو ساعته پیش‌فرض اعلان می‌گیرد', () {
      const s = Session(day: 0, start: 8, end: 10);
      expect(s.alarmOff, isNull);
      expect(s.alarmEnabled, isTrue);
      expect(s.isOneHour, isFalse);
    });

    test('جلسهٔ تک‌ساعته پیش‌فرض بی‌اعلان است', () {
      const s = Session(day: 0, start: 7.5, end: 8.5);
      expect(s.isOneHour, isTrue);
      expect(s.alarmOff, isNull);
      expect(s.alarmEnabled, isFalse);
      expect(s.alarmOffEffective, isTrue);
    });

    test('کاربر می‌تواند تک‌ساعته را صریحاً روشن کند', () {
      const s = Session(day: 0, start: 7.5, end: 8.5, alarmOff: false);
      expect(s.isOneHour, isTrue);
      expect(s.alarmEnabled, isTrue);
    });

    test('کاربر می‌تواند جلسهٔ دو ساعته را صریحاً خاموش کند', () {
      const s = Session(day: 0, start: 8, end: 10, alarmOff: true);
      expect(s.alarmEnabled, isFalse);
    });

    test('مرزها: ۵۹:۵۹ و ۱:۰۰:۰۱ تک‌ساعته حساب نمی‌شوند', () {
      // ۱ ساعت و ۲ دقیقه
      expect(const Session(day: 0, start: 8, end: 9.0333).isOneHour, isFalse);
      // ۵۸ دقیقه
      expect(const Session(day: 0, start: 8, end: 8.9667).isOneHour, isFalse);
      // دقیقاً ۱ ساعت
      expect(const Session(day: 0, start: 8, end: 9).isOneHour, isTrue);
      expect(const Session(day: 0, start: 13.5, end: 14.5).isOneHour, isTrue);
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
      // resetAlarmOff برش می‌گرداند به «پیش‌فرض»
      expect(off.copyWith(resetAlarmOff: true).alarmOff, isNull);
    });

    test('alarmOff در JSON ذخیره و بازگردانی می‌شود (هر سه حالت)', () {
      for (final v in <bool?>[true, false, null]) {
        final s = Session(day: 2, start: 10, end: 12, room: '۲۰۴', type: 'عملی', alarmOff: v);
        final back = Session.fromJson(s.toJson());
        expect(back.alarmOff, v, reason: 'مقدار $v گم شد');
        expect(back.day, 2);
        expect(back.room, '۲۰۴');
      }
    });

    test('جلسهٔ پیش‌فرض کلید alarmOff را در JSON نمی‌نویسد (حجم کمتر)', () {
      const s = Session(day: 0, start: 8, end: 10);
      expect(s.toJson().containsKey('alarmOff'), isFalse);
    });

    test('ذخیره/بازگردانی، پیش‌فرض تک‌ساعته را حفظ می‌کند', () {
      const oneHour = Session(day: 0, start: 7.5, end: 8.5);
      final back = Session.fromJson(oneHour.toJson());
      expect(back.isOneHour, isTrue);
      expect(back.alarmEnabled, isFalse, reason: 'پیش‌فرض تک‌ساعته بعد از ذخیره گم شد');

      const normal = Session(day: 0, start: 8, end: 10);
      expect(Session.fromJson(normal.toJson()).alarmEnabled, isTrue);
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
          expect(s.alarmOff, isNull, reason: 'جلسهٔ «${c.name}» بدون دلیل صریح خاموش شده');
          // پیش‌فرض: تک‌ساعته بی‌اعلان، بقیه اعلان‌دار
          expect(s.alarmEnabled, !s.isOneHour,
              reason: 'جلسهٔ «${c.name}» ساعت ${s.start} پیش‌فرض اشتباه دارد');
        }
      }
    });
  });
}
