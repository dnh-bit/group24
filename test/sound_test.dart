import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/services/settings_service.dart';

/// صداهای آلارم: هر گزینه باید برچسب و توضیح داشته باشد و حالت «موسیقی خودم»
/// باید در تنظیمات ذخیره شود. باگ واقعی که این تست‌ها از آن محافظت می‌کنند:
/// گزینهٔ «زنگ گوشی» بی‌صدا بود چون URI خالی به پلاگین داده می‌شد.
void main() {
  group('گزینه‌های صدا', () {
    test('همهٔ گزینه‌ها برچسب و توضیح فارسی دارند', () {
      for (final v in AlarmSound.values) {
        expect(v.label.trim(), isNotEmpty, reason: '${v.name} برچسب ندارد');
        expect(v.hint.trim(), isNotEmpty, reason: '${v.name} توضیح ندارد');
      }
    });

    test('«موسیقی خودم» وجود دارد', () {
      expect(AlarmSound.values.contains(AlarmSound.custom), isTrue);
      expect(AlarmSound.custom.label, contains('موسیقی'));
    });

    test('«بی‌صدا» و «فقط لرزش» صدا ندارند', () {
      // این دو هیچ URI صوتی نمی‌گیرند — توضیحشان باید همین را بگوید
      expect(AlarmSound.silent.label, contains('بی‌صدا'));
      expect(AlarmSound.vibrateOnly.label, contains('لرزش'));
      final hint = AlarmSound.vibrateOnly.hint;
      expect(hint.contains('لرزش') || hint.contains('می‌لرزد'), isTrue,
          reason: 'توضیح «فقط لرزش» باید به لرزش اشاره کند: $hint');
    });

    test('«زنگ اعلان گوشی» حذف شده است', () {
      // این گزینه روی بخش بزرگی از گوشی‌ها بی‌صدا بود (getDefaultUri → null)
      for (final v in AlarmSound.values) {
        expect(v.name, isNot('systemAlarm'),
            reason: 'گزینهٔ بی‌صدا نباید برگردد');
      }
      expect(AlarmSound.values.length, 4);
    });

    test('فقط گزینه‌های تضمینی صدا باقی مانده‌اند', () {
      expect(AlarmSound.values, contains(AlarmSound.appAlarm));
      expect(AlarmSound.values, contains(AlarmSound.custom));
      expect(AlarmSound.values, contains(AlarmSound.vibrateOnly));
      expect(AlarmSound.values, contains(AlarmSound.silent));
    });
  });

  group('مهاجرت ایندکس ذخیره‌شده', () {
    /// نقشهٔ نسخهٔ قدیم: 0=appAlarm, 1=systemAlarm(حذف شد), 2=vibrateOnly,
    /// 3=silent, 4=custom. اگر این مهاجرت نباشد، کاربری که «زنگ گوشی» را
    /// انتخاب کرده بود بی‌دلیل «فقط لرزش» می‌گیرد.
    AlarmSound migrate(int? raw) {
      if (raw == null) return AlarmSound.appAlarm;
      const legacy = <int, AlarmSound>{
        0: AlarmSound.appAlarm,
        1: AlarmSound.appAlarm,
        2: AlarmSound.vibrateOnly,
        3: AlarmSound.silent,
        4: AlarmSound.custom,
      };
      return legacy[raw] ?? AlarmSound.appAlarm;
    }

    test('ایندکس ۱ (زنگ گوشیِ حذف‌شده) به زنگ برنامه می‌رود، نه فقط لرزش', () {
      expect(migrate(1), AlarmSound.appAlarm);
      expect(migrate(1), isNot(AlarmSound.vibrateOnly));
    });

    test('بقیهٔ ایندکس‌ها دست‌نخورده می‌مانند', () {
      expect(migrate(0), AlarmSound.appAlarm);
      expect(migrate(2), AlarmSound.vibrateOnly);
      expect(migrate(3), AlarmSound.silent);
      expect(migrate(4), AlarmSound.custom);
    });

    test('ایندکس نامعتبر و خالی به زنگ برنامه می‌رود', () {
      expect(migrate(null), AlarmSound.appAlarm);
      expect(migrate(9), AlarmSound.appAlarm);
      expect(migrate(-1), AlarmSound.appAlarm);
    });
  });

  group('ذخیرهٔ موسیقی انتخاب‌شده', () {
    test('پیش‌فرض: هیچ موسیقی‌ای انتخاب نشده', () {
      const s = AppSettings();
      expect(s.customSoundUri, isEmpty);
      expect(s.customSoundName, isEmpty);
      expect(s.alarmSound, AlarmSound.appAlarm);
    });

    test('copyWith موسیقی و نامش را حفظ می‌کند', () {
      const s = AppSettings();
      final t = s.copyWith(
        customSoundUri: 'content://media/external/audio/media/42',
        customSoundName: 'آهنگ من',
        alarmSound: AlarmSound.custom,
      );
      expect(t.customSoundUri, 'content://media/external/audio/media/42');
      expect(t.customSoundName, 'آهنگ من');
      expect(t.alarmSound, AlarmSound.custom);

      // تغییر بقیهٔ تنظیمات، موسیقی را از بین نمی‌برد
      final u = t.copyWith(minutesBefore: 20);
      expect(u.customSoundUri, t.customSoundUri);
      expect(u.customSoundName, t.customSoundName);
      expect(u.alarmSound, AlarmSound.custom);
    });

    test('جابه‌جایی بین گزینه‌ها موسیقی را پاک نمی‌کند', () {
      const s = AppSettings();
      final withMusic = s.copyWith(
        customSoundUri: 'content://x/1',
        customSoundName: 'file.mp3',
        alarmSound: AlarmSound.custom,
      );
      final switched = withMusic.copyWith(alarmSound: AlarmSound.vibrateOnly);
      expect(switched.alarmSound, AlarmSound.vibrateOnly);
      // موسیقی برای انتخاب دوباره باقی می‌ماند
      expect(switched.customSoundUri, 'content://x/1');
      expect(switched.customSoundName, 'file.mp3');
    });
  });
}
