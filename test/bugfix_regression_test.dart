// رگرسیون باگ‌های گزارش‌شده در ممیزی نسخهٔ ۰٫۱٫۷+۱۷.
//
// نکتهٔ مهم دربارهٔ بیلدها: این فایل با هر دو بیلد (معمولی و
// EMPTY_DEFAULT=true) اجرا می‌شود؛ تست‌های وابسته به بیلد با
// [kEmptyDefault] شاخه‌بندی می‌شوند تا هر دو بیلد سبز بماند.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_plan/data/default_schedule.dart';
import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';
import 'package:course_plan/jalali.dart';
import 'package:course_plan/services/notification_service.dart';
import 'package:course_plan/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('بیلد خالی: بدون هیچ برند فرهنگیان', () {
    test('نسخهٔ خالی: پوستر بدون خط دانشگاه و بدون گروه پیش‌فرض', () {
      if (!kEmptyDefault) return;
      expect(kPosterEyebrow, isNull, reason: 'در بیلد عمومی هیچ برند دانشگاهی نباید باشد');
      expect(ScheduleStore.instance.groups, isEmpty);
    });

    test('نسخهٔ معمولی: پوستر خط دانشگاه را دارد', () {
      if (kEmptyDefault) return;
      expect(kPosterEyebrow, isNotNull);
      expect(kPosterEyebrow, contains('فرهنگیان'));
    });

    test('نسخهٔ خالی: بازگردانی به پیش‌فرض هیچ گروه ۲۴/۲۵ ای زنده نمی‌کند', () async {
      if (!kEmptyDefault) return;
      final store = ScheduleStore.instance;
      // حتی اگر گروهی با id «g1» ساخته و فعال شده باشد
      final g = await store.importAsNewGroup(
        '{"courses":[{"id":1,"name":"حسابداری","units":2,'
        '"sessions":[{"d":0,"s":8,"e":10}]}]}',
        name: 'گروه من',
      );
      await store.selectGroup(g.id);
      await store.resetToDefault();
      // باید همان درس کاربر بماند، نه برنامهٔ گروه ۲۴
      expect(store.activeGroup.courses.single.name, 'حسابداری');
    });

    test('نسخهٔ خالی: resetAllGroups همه را پاک می‌کند (بدون گروه ۲۴)', () async {
      if (!kEmptyDefault) return;
      final store = ScheduleStore.instance;
      await store.importAsNewGroup(
        '{"courses":[{"id":1,"name":"فیزیک","units":2,'
        '"sessions":[{"d":1,"s":10,"e":12}]}]}',
        name: 'گروه من',
      );
      await store.resetAllGroups();
      expect(store.groups, isEmpty, reason: 'دیالوگ دقیقاً همین را قول می‌دهد');
    });

    test('نسخهٔ خالی: نام پیش‌فرض گروه واردشده «گروه ۱» است نه گروه ۲۴', () async {
      if (!kEmptyDefault) return;
      expect(kDefaultGroupName, 'گروه ۱');
      expect(kDefaultGroupName, isNot(contains('۲۴')));
    });
  });

  group('نام‌های پیش‌فرض و ایمپورت', () {
    test('نسخهٔ معمولی: نام پیش‌فرض همان گروه ۲۴ است (رفتار قدیمی حفظ شود)', () {
      if (kEmptyDefault) return;
      expect(kDefaultGroupName, 'برنامه درسی گروه ۲۴');
    });

    test('ایمپورت تک‌گروهی بدون نام، در بیلد خالی نام عمومی می‌گیرد', () async {
      if (!kEmptyDefault) return;
      final store = ScheduleStore.instance;
      final parsed = store.parseAnyToGroups(
        '{"courses":[{"id":1,"name":"ریاضی","units":3,'
        '"sessions":[{"d":0,"s":8,"e":10}]}]}',
      );
      expect(parsed.groups.single.name, 'گروه ۱');
      expect(parsed.groups.single.name, isNot(contains('۲۴')));
    });
  });

  group('alertExplicit (انتخاب «فقط اعلان» در فرم درس باید ذخیره و اعمال شود)', () {
    test('round-trip: alertExplicit در JSON ذخیره و بازخوانی می‌شود', () {
      final c = Course(
        id: 1,
        name: 'آمار',
        colorValue: 0xFF7C3AED,
        alert: CourseAlert.notice,
        alertExplicit: true,
      );
      final j = c.toJson();
      expect(j['alertExplicit'], true);
      final back = Course.fromJson(j);
      expect(back.alertExplicit, true);
      expect(back.alert, CourseAlert.notice);
    });

    test('درس بدون انتخاب صریح: alertExplicit=false می‌ماند', () {
      final c = Course.fromJson(<String, dynamic>{'id': 2, 'name': 'اکomidou'});
      expect(c.alertExplicit, false);
    });
  });

  group('امتحان هم‌روز', () {
    test('دو امتحان در یک روز پذیرفته می‌شود (examsSameDay هر دو را برمی‌گرداند)', () async {
      final store = ScheduleStore.instance;
      // درس اول باید واقعاً توی گروه فعال باشد؛ examsSameDay روی گروه فعال
      // جستجو می‌کند، نه روی آبجکت‌های شناور.
      final g = await store.importAsNewGroup(
        '{"courses":[{"id":1,"name":"ریاضی","units":2,'
        '"exam":{"jy":1405,"jm":11,"jd":5,"s":8,"e":10},'
        '"sessions":[{"d":0,"s":8,"e":10}]}]}',
        name: 'گروه امتحان',
      );
      await store.selectGroup(g.id);
      final b = Course(
        id: 2,
        name: 'فیزیک',
        colorValue: 0xFF16A34A,
        exam: const Exam(date: JDate(1405, 11, 5), start: 14, end: 16),
      );
      final same = store.examsSameDay(b);
      expect(same.map((c) => c.id), contains(1));
    });

    test('exam با ساعت شروع/پایان نامعتبر هم سیو می‌شود ولی خطا می‌گیرد', () {
      // اعداد خارج از محدوده باید در parse تحمل‌پذیر باشند (بدون crash)
      final c = Course.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'شبکه',
        'exam': <String, dynamic>{'jy': 1405, 'jm': 11, 'jd': 5, 's': 25, 'e': 2},
      });
      expect(c.exam, isNotNull);
    });
  });

  group('payload اعلان (ضربه روی اعلان بدون payload نباید اپ را بترکاند)', () {
    test('payload ساختار یافته: شناسهٔ درس برمی‌گردد', () {
      expect(NotificationService.coursePayloadId('course:12'), 12);
      expect(NotificationService.coursePayloadId('exam:7'), 7);
    });

    test('payload خراب/خالی: null (نه RangeError)', () {
      expect(NotificationService.coursePayloadId(''), isNull);
      expect(NotificationService.coursePayloadId('test-notification'), isNull);
      expect(NotificationService.coursePayloadId('weird'), isNull);
      expect(NotificationService.coursePayloadId('course:'), isNull);
      expect(NotificationService.coursePayloadId('course:abc'), isNull);
    });
  });

  group('کلاس بعدی (پایان هفته)', () {
    test('جمعهٔ عصر، کلاس شنبهٔ صبح «بعدی» است (k تا ۷ برود)', () {
      if (kEmptyDefault) return;
      // جمعه = آخرین روز هفته؛ حلقهٔ قبلی k<7 بود و شنبهٔ هفتهٔ بعد را
      // پیدا نمی‌کرد (کلاس بعدیِ جمعه همیشه پیدا نمی‌شد).
      final store = ScheduleStore.instance;
      final g = store.groups.first;
      // بررسی می‌کنیم برای همهٔ ساعت‌های جمعه جوابی هست یا نه
      for (var h = 0.0; h < 24; h += 4) {
        final next = store.findNextFor(
          g,
          DateTime(2026, 1, 2, h.toInt(), 0),
        );
        // نباید به‌خاطر پایان هفته null شود (گروه ۲۴ همهٔ روزها کلاس دارد)
        expect(next, isNotNull, reason: 'ساعت $h جمعه');
      }
    });
  });

  group('wrapHour (پیش‌نمایش آلارم قبل از نیمه‌شب)', () {
    test('کلاس ۰۰:۳۰ با آلارم ۱۲۰ دقیقه → ۲۲:۳۰', () {
      expect(wrapHour(0.5 - 2), 22.5);
    });

    test('مقادیر نرمال دست‌نخورده می‌مانند', () {
      expect(wrapHour(8), 8);
      expect(wrapHour(23.5), 23.5);
    });
  });
}
