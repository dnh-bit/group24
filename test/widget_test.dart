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
    // یکشنبه ساعت ۱۰ صبح → فضاهای تربیتی (۹:۳۰ تا ۱۱:۳۰) در حال برگزاریه
    final sunday = DateTime(2026, 10, 18, 10, 0);
    final next = ScheduleStore.instance.findNext(sunday)!;
    expect(next.ref.course.id, 8);
    expect(next.ongoing, true);
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

    test('شمارهٔ کلاس‌های تکراری در برنامه نیست', () {
      final rooms = <String, int>{};
      for (final c in ScheduleStore.instance.courses) {
        for (final s in c.sessions) {
          if (!s.room.startsWith('کلاس ')) continue;
          rooms[s.room] = (rooms[s.room] ?? 0) + 1;
        }
      }
      // ۲۰۴ فقط برای تاریخ تمدن، ۴۰۶ فقط برای آسیب‌شناسی (JDate/room یکتا)
      expect(rooms['کلاس ۲۰۴'], 1);
      expect(rooms['کلاس ۴۰۶'], 1);
    });
  });

  group('course groups', () {
    tearDown(() async {
      // هر تست را با گروه اصلی شروع کن
      await ScheduleStore.instance.resetAllGroups();
    });

    test('پیش‌فرض یک گروه دارد', () {
      final store = ScheduleStore.instance;
      expect(store.groups.length, 1);
      expect(store.activeGroupId, 'g1');
      expect(store.courses.length, 9);
    });

    test('افزودن گروه، فعالش می‌کند و درس‌ها جدا می‌مانند', () async {
      final store = ScheduleStore.instance;
      final before = store.courses.length;

      await store.addGroup(name: 'گروه ۲۵');
      expect(store.groups.length, 2);
      expect(store.activeGroup.name, 'گروه ۲۵');
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

    test('تغییر نام گروه', () async {
      final store = ScheduleStore.instance;
      await store.renameGroup('g1', 'ترم دوم');
      expect(store.activeGroup.name, 'ترم دوم');
    });

    test('آخرین گروه پاک نمی‌شه', () async {
      final store = ScheduleStore.instance;
      expect(await store.removeGroup('g1'), false);
      expect(store.groups.length, 1);
    });

    test('حذف گروه فعال، گروه دیگری را فعال می‌کند', () async {
      final store = ScheduleStore.instance;
      await store.addGroup(name: 'موقت');
      final id = store.activeGroupId;
      expect(await store.removeGroup(id), true);
      expect(store.activeGroupId, 'g1');
    });

    test('پشتیبان کامل رفت‌وبرگشت دارد', () async {
      final store = ScheduleStore.instance;
      await store.addGroup(name: 'گروه دوم', copyCoursesFromActive: true);
      final dump = store.exportJson();

      await store.resetAllGroups();
      expect(store.groups.length, 1);

      final n = await store.importJson(dump);
      expect(n, 18); // ۹ درس در هر گروه
      expect(store.groups.length, 2);
      expect(store.groups.map((g) => g.name), contains('گروه دوم'));
    });

    test('پشتیبان تک‌گروهی فقط گروه فعال را عوض می‌کند', () async {
      final store = ScheduleStore.instance;
      const single = CourseGroup(
        id: 'g9',
        name: 'تنها',
        courses: [
          Course(
            id: 1,
            name: 'درس تست',
            colorValue: 0xFF2F6F8F,
            sessions: [Session(day: 0, start: 8, end: 10, room: 'کلاس ۱۰۱')],
          ),
        ],
      );
      final payload = '{"group":${single.toJson()}}'.replaceAll("'", '"');
      await store.importJson(payload);
      expect(store.courses.length, 1);
      expect(store.courses.single.name, 'درس تست');
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
