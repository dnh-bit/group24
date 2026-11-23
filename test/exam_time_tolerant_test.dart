import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/backup_code.dart';
import 'package:course_plan/data/models.dart';

/// رگرسیون باگ گزارش‌شده از استفادهٔ واقعی (۱۴۰۵/۰۹/۰۱):
/// خروجی واقعی جمنای از روی «تاییدیهٔ انتخاب واحد» برای درس دوم خط
/// `x|1405|10|21|||` داشت — تاریخ امتحان بود ولی ساعت نبود (در تاییدیه
/// ساعت امتحان نمی‌آید). پارسر کل ایمپورت را با خطای
/// «امتحان درس … نامعتبره (تاریخ/ساعت)» رد می‌کرد.
const String kGeminiOutput = '''
PLAN|name=نیم‌سال اول ۱۴۰۶-۱۴۰۵
c1|تاریخ فرهنگ و تمدن اسلام و ایران|تاریخ فرهنگ و تمدن|علی یزدانی احمد آبادی|معارف|2|0
s|3|15.5|17.5|کلاس ۴۰۳|نظری
x|1405|10|29|8|10|
c2|زیبایی شناسی و حکمت هنر اسلامی|زیبایی شناسی و هنر|مجتبی محسنی|تخصصی|2|1
s|2|15.5|17.5|کلاس ۳۰۷|نظری
x|1405|10|21|||
c3|آسیب شناسی اجتماعی|آسیب شناسی اجتماعی|زهیر مصطفی بلوردی|تخصصی|2|2
s|3|17.5|19.5|کلاس ۴۰۷|نظری
x|1405|10|27|12.5|14.5|
c4|آموزش والدین و شیوه های فرزند پروری|آموزش والدین|عزت اله ملک پور افشار|تخصصی|2|3
s|1|17.5|19.5|عمومی|نظری
x|1405|10|26|8|10|
c5|کارگاه نمایشنامه نویسی|نمایشنامه نویسی|حمید نژادی|تخصصی|1|4
s|1|13.5|15.5|کلاس ۲۰۱|عملی
s|1|19.5|20.5|کلاس مجازی|عملی
c6|کارورزی ۳|کارورزی ۳|میثم دوست محمدی|کارورزی|2|5
s|2|7.5|15.5|عمومی|عملی
c7|نمایش ۲ (تئاتر صحنه ای و نمایش عروسکی)|نمایش ۲|حمید نژادی|تخصصی|2|6
s|5|19.5|20.5|کلاس مجازی|نظری
s|0|13.5|15.5|کلاس ۳۰۶|عملی
x|1405|10|23|8|10|
c8|آشنایی با فضاهای تربیتی دانش آموزان|فضاهای تربیتی|محسن سعیدی|تخصصی|2|7
s|4|7.5|8.5|کلاس ۳۰۷|نظری
s|1|9.5|11.5|کلاس ۳۰۳|عملی
x|1405|10|22|8|10|
c9|مدیریت و برنامه ریزی امور فرهنگی و تربیتی|مدیریت امور فرهنگی|امیر سلطانی نژاد|تخصصی|2|8
s|3|19.5|20.5|کلاس ۲۰۱|نظری
s|1|15.5|17.5|کلاس ۵۰۱|عملی
x|1405|10|20|8|10|
''';

void main() {
  group('امتحان بدون ساعت (خروجی واقعی جمنای)', () {
    test('کل خروجی جمنای بدون خطا وارد می‌شود — ۹ درس', () {
      final r = parseCompactPlan(kGeminiOutput);
      expect(r.courses.length, 9);
      expect(r.name, 'نیم‌سال اول ۱۴۰۶-۱۴۰۵');
    });

    test('امتحان بدون ساعت: تاریخ می‌ماند و ساعت «نامعلوم» می‌ماند (نه ۸ تا ۱۰ ساختگی)', () {
      final r = parseCompactPlan(kGeminiOutput);
      final c2 = r.courses.firstWhere((c) => c.id == 2);
      expect(c2.exam, isNotNull);
      expect(c2.exam!.date.y, 1405);
      expect(c2.exam!.date.m, 10);
      expect(c2.exam!.date.d, 21);
      expect(c2.exam!.start, isNull, reason: 'ساعت اعلام نشده بود؛ نباید ساعت ساخته شود');
      expect(c2.exam!.end, isNull);
      expect(c2.exam!.hasTime, isFalse);
      expect(c2.exam!.timeText, '');
    });

    test('امتحان‌های کامل دست نمی‌خورند', () {
      final r = parseCompactPlan(kGeminiOutput);
      final c1 = r.courses.firstWhere((c) => c.id == 1);
      expect(c1.exam!.start, 8);
      expect(c1.exam!.end, 10);
      final c3 = r.courses.firstWhere((c) => c.id == 3);
      expect(c3.exam!.start, 12.5);
      expect(c3.exam!.end, 14.5);
    });

    test('فقط ساعت پایان خالی: شروع می‌ماند و پایان نامعلوم می‌ماند', () {
      final r = parseCompactPlan('''
PLAN|name=ترم تست
c1|ریاضی|ریاضی|استاد الف|پایه|3|0
s|0|8|10|کلاس ۱|نظری
x|1405|11|3|9|
''');
      expect(r.courses.single.exam!.start, 9);
      expect(r.courses.single.exam!.end, isNull, reason: 'پایانِ نیامده را نباید ساخت');
    });

    test('JSON: امتحان بدون ساعت در رفت‌وبرگردشت بدون ساعت می‌ماند', () {
      final e = Exam.fromJson(<String, dynamic>{'jy': 1405, 'jm': 10, 'jd': 21});
      expect(e.start, isNull);
      expect(e.end, isNull);
      final back = Exam.fromJson(e.toJson());
      expect(back.start, isNull);
      expect(back.end, isNull);
      expect(back.date.d, 21);
    });

    test('JSON: امتحان با ساعت دقیق، همان ساعت را نگه می‌دارد', () {
      final e = Exam.fromJson(<String, dynamic>{'jy': 1405, 'jm': 10, 'jd': 21, 's': 9.5, 'e': 11.5});
      expect(e.start, 9.5);
      expect(e.end, 11.5);
      expect(e.hasTime, isTrue);
      expect(e.timeText, isNotEmpty);
    });

    test('تاریخ امتحان نامعتبر: فقط همان امتحان رد می‌شود، بقیهٔ برنامه می‌آید', () {
      final r = parseCompactPlan('''
PLAN|name=ترم تست
c1|ریاضی|ریاضی|استاد الف|پایه|3|0
s|0|8|10|کلاس ۱|نظری
x|1405|13|3|8|10|
c2|فیزیک|فیزیک|استاد ب|پایه|3|1
s|1|8|10|کلاس ۲|نظری
x|1405|11|5|8|10|
''');
      expect(r.courses.length, 2);
      expect(r.courses[0].exam, isNull, reason: 'ماه ۱۳ وجود ندارد؛ امتحانش رد می‌شود');
      expect(r.courses[1].exam, isNotNull);
    });
  });
}
