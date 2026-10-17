import 'package:flutter_test/flutter_test.dart';
import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';
import 'package:course_plan/jalali.dart';
import 'package:course_plan/utils.dart';

void main() {
  test('Persian digits & time format', () {
    expect(fa(15), '۱۵');
    expect(fmtTime(7.5), '۰۷:۳۰');
  });

  test('jalali <-> gregorian round trip', () {
    expect(gregorianToJalali(2026, 10, 13), [1405, 7, 21]);
    expect(jalaliToGregorian(1405, 10, 29), [2027, 1, 19]);
    expect(jalaliMonthLength(1405, 12), 29); // اسفند ۱۴۰۵ کبیسه نیست
  });

  test('next class is found', () {
    // یکشنبه ساعت ۹ صبح → فضاهای تربیتی (۸ تا ۱۰) در حال برگزاریه
    final sunday = DateTime(2026, 10, 18, 9, 0);
    final next = ScheduleStore.instance.findNext(sunday)!;
    expect(next.ref.course.id, 8);
    expect(next.ongoing, true);
  });

  test('next class ignores one-hour sessions', () {
    // یکشنبه ساعت ۱۶: جلسه‌های قبلی گذشته‌اند و کارگاهِ تک‌ساعتهٔ ۱۹:۳۰
    // برگزار نمی‌شه → کلاس بعدی باید کارورزی (دوشنبه) باشه
    final sunday = DateTime(2026, 10, 18, 16, 0);
    final next = ScheduleStore.instance.findNext(sunday)!;
    expect(next.ref.course.id, 6);
    expect(next.daysAhead, 1);
  });

  test('default schedule has no conflicts', () {
    expect(ScheduleStore.instance.conflicts(), isEmpty);
  });

  group('default room numbers', () {
    test('تاریخ تمدن اسلامی → کلاس ۲۰۴', () {
      final c = ScheduleStore.instance.byId(1)!;
      expect(c.sessions.single.room, 'کلاس ۲۰۴');
    });

    test('آسیب‌شناسی اجتماعی → کلاس ۴۰۶', () {
      final c = ScheduleStore.instance.byId(3)!;
      expect(c.sessions.single.room, 'کلاس ۴۰۶');
    });

    test('هیچ دو کلاسی هم‌زمان در یک اتاق نیستند', () {
      // اتاق می‌تواند بین دو درس مشترک باشد (روز/ساعت متفاوت)، ولی نباید
      // دو جلسهٔ هم‌پوشان در یک اتاق بیفتد.
      final store = ScheduleStore.instance;
      for (final a in store.allSessions) {
        for (final b in store.allSessions) {
          if (a.course.id == b.course.id && a.index == b.index) continue;
          if (!a.session.overlaps(b.session)) continue;
          if (a.session.room.isEmpty || a.session.room == 'عمومی') continue;
          expect(
            a.session.room == b.session.room,
            isFalse,
            reason: '${a.course.shortName} و ${b.course.shortName} '
                'هم‌زمان در ${a.session.room}',
          );
        }
      }
    });
  });

  group('course groups', () {
    tearDown(() async {
      // هر تست را با گروه اصلی شروع کن
      await ScheduleStore.instance.resetAllGroups();
    });

    test('پیش‌فرض دو گروه دارد: گروه ۲۴ و گروه ۲۵', () {
      final store = ScheduleStore.instance;
      expect(store.groups.length, 2);
      expect(store.activeGroupId, 'g1');
      expect(store.groups[0].name, 'برنامه درسی گروه ۲۴');
      expect(store.groups[1].name, 'برنامه درسی گروه ۲۵');
      expect(store.groups[0].courses.length, 9);
      expect(store.groups[1].courses.length, 9);
      expect(store.courses.length, 9); // گروه فعال = گروه ۲۴
    });

    test('افزودن گروه، فعالش می‌کند و درس‌ها جدا می‌مانند', () async {
      final store = ScheduleStore.instance;
      final before = store.courses.length;

      await store.addGroup(name: 'ترم دیگر');
      expect(store.groups.length, 3);
      expect(store.activeGroup.name, 'ترم دیگر');
      expect(store.courses, isEmpty); // گروه جدید بدون درس

      // گروه اول دست‌نخورده
      await store.selectGroup('g1');
      expect(store.courses.length, before);
    });

    test('کپی درس‌ها از گروه فعال', () async {
      final store = ScheduleStore.instance;
      final before = store.courses.length;
      await store.addGroup(name: 'کپی', copyCoursesFromActive: true);
      expect(store.courses.length, before);
      // تغییر در گروه جدید روی گروه قبلی اثر نداره
      await store.remove(store.courses.first.id);
      await store.selectGroup('g1');
      expect(store.courses.length, before);
    });

    test('نام خالی → نام پیش‌فرض شماره‌دار', () async {
      final store = ScheduleStore.instance;
      await store.addGroup();
      expect(store.activeGroup.name, isNotEmpty);
      expect(store.activeGroup.name.contains('گروه'), true);
    });

    test('برنامهٔ گروه ۲۵: مکان LMS و ساعتِ تغییر یافتهٔ تاریخ تمدن', () {
      final store = ScheduleStore.instance;
      final g25 = store.groups.firstWhere((g) => g.name == 'برنامه درسی گروه ۲۵');
      expect(g25.courses.length, 9);
      // درس ۱ = تاریخ تمدن: پنج‌شنبه ۱۸ تا ۲۰ در سامانهٔ LMS
      final history = g25.courses.first;
      expect(history.name, 'تاریخ فرهنگ و تمدن اسلام و ایران');
      expect(history.sessions.single.day, 5);
      expect(history.sessions.single.start, 18.0);
      expect(history.sessions.single.end, 20.0);
      expect(history.sessions.single.room, 'سامانه LMS');
      // همهٔ جلسه‌های گروه ۲۵ محل برگزاری LMS دارند
      for (final c in g25.courses) {
        for (final s in c.sessions) {
          expect(s.room, 'سامانه LMS', reason: c.name);
        }
      }
    });

    test('تغییر نام گروه', () async {
      final store = ScheduleStore.instance;
      await store.renameGroup('g1', 'ترم دوم');
      expect(store.activeGroup.name, 'ترم دوم');
    });

    test('آخرین گروه پاک نمی‌شه', () async {
      final store = ScheduleStore.instance;
      expect(store.groups.length, 2);
      expect(await store.removeGroup('g2'), true);
      expect(store.groups.length, 1);
      expect(await store.removeGroup('g1'), false);
      expect(store.groups.length, 1);
    });

    test('حذف گروه فعال، گروه دیگری را فعال می‌کند', () async {
      final store = ScheduleStore.instance;
      await store.addGroup(name: 'موقت');
      final id = store.activeGroupId;
      expect(await store.removeGroup(id), true);
      expect(store.activeGroupId, anyOf('g1', 'g2'));
    });

    test('پشتیبان کامل رفت‌وبرگشت دارد', () async {
      final store = ScheduleStore.instance;
      await store.addGroup(name: 'گروه دوم', copyCoursesFromActive: true);
      final dump = store.exportJson();

      await store.resetAllGroups();
      expect(store.groups.length, 2); // دو گروه پیش‌فرض

      final n = await store.importJson(dump);
      expect(n, 27); // ۹ درس در هر گروه × ۳ گروه
      expect(store.groups.length, 3);
      expect(store.groups.map((g) => g.name), contains('گروه دوم'));
    });

    test('پشتیبان تک‌گروهی فقط گروه فعال را عوض می‌کند', () async {
      final store = ScheduleStore.instance;
      // یک پشتیبان تک‌گروهی واقعی (JSON، نه toString مپ دارت)
      final payload = '''
{"group":{"id":"g9","name":"تنها","courses":[
  {"id":1,"name":"درس تست","short":"","prof":"","kind":"تخصصی","units":2,
   "color":637931535,"sessions":[{"d":0,"s":8.0,"e":10.0,"room":"کلاس ۱۰۱","t":"نظری"}],
   "note":"","muted":false}
]}}''';
      await store.importJson(payload);
      expect(store.courses.length, 1);
      expect(store.courses.single.name, 'درس تست');
      expect(store.courses.single.sessions.single.room, 'کلاس ۱۰۱');
    });

    test('شمارهٔ کلاس در پشتیبان حفظ می‌شود', () async {
      final store = ScheduleStore.instance;
      final dump = store.exportJson();
      await store.resetAllGroups();
      await store.importJson(dump);
      expect(store.byId(1)!.sessions.single.room, 'کلاس ۲۰۴');
      expect(store.byId(3)!.sessions.single.room, 'کلاس ۴۰۶');
    });

    test('logout: مدل گروه سریالایز/دیسریالایز می‌شود', () {
      const g = CourseGroup(
        id: 'gX',
        name: 'آزمایشی',
        courses: [
          Course(id: 7, name: 'x', colorValue: 0xFF000000, units: 3),
        ],
      );
      final back = CourseGroup.fromJson(g.toJson());
      expect(back.id, 'gX');
      expect(back.name, 'آزمایشی');
      expect(back.courses.single.id, 7);
      expect(back.totalUnits, 3);
    });
  });
}
