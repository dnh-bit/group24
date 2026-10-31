import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/default_schedule.dart';
import 'package:course_plan/data/models.dart';
import 'package:course_plan/utils.dart';

/// تغییرهای برنامهٔ درسی که کاربر دستی اعلام می‌کند باید در این فایل
/// قفل شوند؛ وگرنه با یک «بازگردانی پیش‌فرض» بی‌سروصدا برمی‌گردند.
void main() {
  /// درس‌های گروه ۲۴ (برنامهٔ اصلی دانشگاه فرهنگیان)
  final g24 = kDefaultCourses;

  Course? byProf(String prof) {
    for (final c in g24) {
      if (c.prof.trim() == prof && c.name.contains('مدیریت و برنامه‌ریزی امور فرهنگی')) {
        return c;
      }
    }
    return null;
  }

  group('درس مدیریت امور فرهنگی و تربیتی (استاد سلطانی‌نژاد) — گروه ۲۴', () {
    test('درس پیدا می‌شود', () {
      expect(byProf('امیر سلطانی‌نژاد'), isNotNull);
    });

    test('جلسهٔ عملی سه‌شنبه ۱۴:۰۰ تا ۱۵:۳۰ است', () {
      final c = byProf('امیر سلطانی‌نژاد')!;
      final onTuesday = c.sessions.where((s) => s.day == 3).toList();
      final target = onTuesday.where((s) => s.start == 14.0 && s.end == 15.5).toList();
      expect(target.length, 1, reason: 'جلسهٔ سه‌شنبه ۱۴-۱۵:۳۰ پیدا نشد');
      expect(target.single.type, 'عملی');
      expect(target.single.room, 'کلاس ۵۰۱');
    });

    test('جلسهٔ یکشنبه ۱۵:۳۰-۱۷:۳۰ دیگر وجود ندارد', () {
      final c = byProf('امیر سلطانی‌نژاد')!;
      final old = c.sessions.where(
        (s) => s.day == 1 && (s.start - 15.5).abs() < 0.001 && (s.end - 17.5).abs() < 0.001,
      );
      expect(old, isEmpty, reason: 'ساعت قدیمی یکشنبه هنوز مانده');
    });

    test('جلسهٔ نظری سه‌شنبه شب دست‌نخورده مانده', () {
      final c = byProf('امیر سلطانی‌نژاد')!;
      final evening = c.sessions.where(
        (s) => s.day == 3 && (s.start - 19.5).abs() < 0.001 && (s.end - 20.5).abs() < 0.001,
      );
      expect(evening.length, 1);
      expect(evening.single.type, 'نظری');
    });

    test('دقیقاً دو جلسه دارد (نه کمتر، نه بیشتر)', () {
      expect(byProf('امیر سلطانی‌نژاد')!.sessions.length, 2);
    });
  });

  group('گروه ۲۴ تداخل ندارد', () {
    test('هیچ دو جلسه‌ای روی هم نمی‌افتند', () {
      final all = <SessionRef>[];
      for (final c in g24) {
        for (var i = 0; i < c.sessions.length; i++) {
          all.add(SessionRef(c, c.sessions[i], i));
        }
      }
      final clashes = <String>[];
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          if (all[i].session.overlaps(all[j].session)) {
            clashes.add('«${all[i].course.shortName}» و «${all[j].course.shortName}» '
                '${kDayNames[all[i].session.day]}');
          }
        }
      }
      expect(clashes, isEmpty, reason: 'تداخل: ${clashes.join(' | ')}');
    });

    test('جلسهٔ جدید سه‌شنبه با درس‌های همان روز تداخل ندارد', () {
      final target = byProf('امیر سلطانی‌نژاد')!
          .sessions
          .firstWhere((s) => s.day == 3 && s.start == 14.0);
      for (final c in g24) {
        if (c.id == byProf('امیر سلطانی‌نژاد')!.id) continue;
        for (final s in c.sessions) {
          expect(s.overlaps(target), isFalse,
              reason: 'با «${c.shortName}» تداخل دارد');
        }
      }
    });
  });

  group('گروه ۲۵ دست‌نخورده است', () {
    test('جلسهٔ نمایشنامه‌نویسی/سلطانی‌نژاد در گروه ۲۵ همان شنبه ۱۷:۳۰-۱۹:۳۰ است', () {
      final c = kG25Courses.firstWhere(
        (c) => c.prof.trim() == 'امیر سلطانی‌نژاد',
        orElse: () => throw StateError('درس پیدا نشد'),
      );
      final sat = c.sessions.where((s) => s.day == 0);
      expect(sat.any((s) => s.start == 17.5 && s.end == 19.5), isTrue);
      // هیچ جلسهٔ سه‌شنبه ۱۴:۰۰ در گروه ۲۵ نباید باشد
      expect(c.sessions.any((s) => s.day == 3 && s.start == 14.0), isFalse);
    });
  });
}
