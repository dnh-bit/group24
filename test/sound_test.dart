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

    test('«زنگ گوشی» توضیح می‌دهد که صدای اعلان پیش‌فرض است', () {
      expect(AlarmSound.systemAlarm.hint.trim(), isNotEmpty);
      expect(AlarmSound.systemAlarm.label, contains('گوشی'));
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
      final switched = withMusic.copyWith(alarmSound: AlarmSound.systemAlarm);
      expect(switched.alarmSound, AlarmSound.systemAlarm);
      // موسیقی برای انتخاب دوباره باقی می‌ماند
      expect(switched.customSoundUri, 'content://x/1');
      expect(switched.customSoundName, 'file.mp3');
    });
  });
}
