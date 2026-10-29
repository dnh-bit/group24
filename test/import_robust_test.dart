import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/backup_code.dart';
import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';

/// ایمپورت باید «قطعی» کار کند: هر شکل معقولی از فایل یا متن که کاربر
/// ممکن است از دانشگاه، واتساپ، تلگرام یا چت‌بات بگیرد.
void main() {
  final store = ScheduleStore.instance;

  // ─────────── فرمت خطی کوتاه چت‌بات ───────────

  test('فرمت خطی: شکل استاندارد', () {
    final text = '''
PLAN|name=ترم اول ۱۴۰۵
c1|آموزش والدین|والدین|دکتر احمدی|تخصصی|2|3
s|1|7.5|9.5|204|نظری
c2|کارگاه نمایشنامه|نمایشنامه|استاد رضایی|عمومی|2|5
s|6|7.5|9.5|LMS|عملی
x|1405|10|29|8|10|سالن
''';
    final r = parseCompactPlan(text);
    expect(r.name, 'ترم اول ۱۴۰۵');
    expect(r.courses.length, 2);
    expect(r.courses[0].sessions.single.day, 1);
    expect(r.courses[1].exam!.date.d, 29);
  });

  test('فرمت خطی: ارقام فارسی و نام روز و ساعت متنی', () {
    final text = '''
PLAN|name=ترم دوم
c۱|ریاضی|ریاضی|استاد|تخصصی|۳|۰
s|یکشنبه|۰۸:۰۰|۱۰:۰۰|کلاس ۱۲|نظری
''';
    final r = parseCompactPlan(text);
    final c = r.courses.single;
    expect(c.units, 3);
    final s = c.sessions.single;
    expect(s.day, 1);
    expect(s.start, 8.0);
    expect(s.end, 10.0);
  });

  test('فرمت خطی: بازهٔ «۸-۱۰» در یک ستون', () {
    final text = '''
c1|فارسی|فارسی||عمومی|2|1
s|0|۸-۱۰|کلاس|نظری
''';
    final s = parseCompactPlan(text).courses.single.sessions.single;
    expect(s.start, 8.0);
    expect(s.end, 10.0);
  });

  test('فرمت خطی: ستون‌های کم و توضیح اضافهٔ چت‌بات', () {
    final text = '''
سلام! این هم برنامه‌ت:

```
PLAN|نام=ترم اول
c1|علوم|علوم|استاد|پایه|2
s|2|10|12
```

امیدوارم مفید باشه. اگه درسی جا افتاده بگو.
''';
    final r = parseCompactPlan(text);
    expect(r.courses.length, 1);
    expect(r.courses.single.sessions.single.start, 10.0);
  });

  // ─────────── JSON: شکل‌های مختلف ───────────

  test('JSON: خروجی خود برنامه (همهٔ گروه‌ها)', () {
    final text = '''
{"app":"course_plan","v":2,"activeGroupId":"g1","groups":[
 {"id":"g1","name":"گروه ۲۴","courses":[
   {"id":1,"name":"ریاضی","units":3,"color":4284779542,
    "sessions":[{"d":0,"s":7.5,"e":9.5,"room":"۲۰۴","t":"نظری"}]}]},
 {"id":"g2","name":"گروه ۲۵","courses":[]}]}
''';
    final r = store.parseAnyToGroups(text);
    expect(r.groups.length, 2);
    expect(r.groups.first.name, 'گروه ۲۴');
    expect(r.groups.first.courses.single.units, 3);
  });

  test('JSON: تک‌گروه زیر کلید group', () {
    final r = store.parseAnyToGroups(
        '{"group":{"name":"ترم اول","courses":[{"id":1,"name":"فلسفه","units":2}]}}');
    expect(r.groups.single.name, 'ترم اول');
    expect(r.groups.single.courses.single.name, 'فلسفه');
  });

  test('JSON: فقط فهرست درس‌ها با کلید courses', () {
    final r = store.parseAnyToGroups(
        '{"name":"ترم سوم","courses":[{"id":1,"name":"آمار","units":2}]}');
    expect(r.suggestedName, 'ترم سوم');
    expect(r.groups.single.courses.single.name, 'آمار');
  });

  test('JSON: آرایهٔ بدون پوشش درس‌ها', () {
    final r = store.parseAnyToGroups(
        '[{"id":1,"name":"الف","units":2},{"id":2,"name":"ب","units":3}]');
    expect(r.groups.single.courses.length, 2);
  });

  test('JSON: آرایهٔ بدون پوشش گروه‌ها', () {
    final r = store.parseAnyToGroups(
        '[{"id":"g1","name":"گ۱","courses":[{"id":1,"name":"الف","units":2}]}]');
    expect(r.groups.single.name, 'گ۱');
  });

  test('JSON: کلیدهای انگلیسی بلند و ساعت متنی و رنگ هگز', () {
    final r = store.parseAnyToGroups('''
{"lessons":[{"id":"x","title":"آموزش والدین","teacher":"دکتر","credits":"۲","color":"#648C16",
 "classes":[{"day":"یکشنبه","start":"08:00","end":"10:00","location":"۱۲","type":"عملی"}]}]}
''');
    final c = r.groups.single.courses.single;
    expect(c.name, 'آموزش والدین');
    expect(c.prof, 'دکتر');
    expect(c.units, 2);
    expect(c.colorValue, 0xFF648C16);
    expect(c.sessions.single.start, 8.0);
    expect(c.sessions.single.type, 'عملی');
  });

  test('JSON: کلیدهای فارسی', () {
    final r = store.parseAnyToGroups('''
{"نام":"ترم اول","درس‌ها":[
 {"id":1,"نام":"فقه","استاد":"حجت‌الاسلام","واحد":2,
  "جلسات":[{"روز":"شنبه","شروع":"۸:۰۰","پایان":"۱۰:۰۰","کلاس":"۱۰۱"}]}]}
''');
    final c = r.groups.single.courses.single;
    expect(c.name, 'فقه');
    expect(c.units, 2);
    expect(c.sessions.single.day, 0);
  });

  test('JSON: ارقام فارسی داخل ساختار', () {
    final r = store.parseAnyToGroups('{"courses":[{"id":۱,"name":"الف","units":۲}]}');
    expect(r.groups.single.courses.single.units, 2);
  });

  test('JSON: کاماهای اضافه و نقل‌قول فارسی', () {
    final r = store.parseAnyToGroups('''
{“courses”:[{“id”:1,“name”:“الف”,“units”:2,},],}
''');
    expect(r.groups.single.courses.single.name, 'الف');
  });

  test('JSON: BOM ویندوزی', () {
    final r = store.parseAnyToGroups('\uFEFF{"courses":[{"id":1,"name":"الف","units":2}]}');
    expect(r.groups.single.courses.length, 1);
  });

  test('JSON: گروه بدون درس مجاز است', () {
    final r = store.parseAnyToGroups('{"groups":[{"id":"g1","name":"خالی","courses":[]}]}');
    expect(r.groups.single.courses, isEmpty);
  });

  // ─────────── کد کوتاه CP2 ───────────

  test('کد CP2 با فاصله و خط شکسته برمی‌گردد', () {
    final json = '{"groups":[{"id":"g1","name":"گ","courses":[{"id":1,"name":"الف","units":2}]}]}';
    final code = encodeBackupCode(json);
    final broken = code.substring(0, 20) + '\n   ' + code.substring(20);
    expect(store.parseAnyToGroups(broken).groups.single.courses.single.name, 'الف');
  });

  // ─────────── خطاهای واقعی باید پیام فارسی بدهند ───────────

  test('خطاها پیام فارسی می‌دهند، نه استثنای خام', () {
    for (final bad in [
      'سلام، این یک متن معمولی است',
      '{"courses": [ اینجا خراب است ]}',
      '{}',
      '[]',
      '{"foo": 1}',
    ]) {
      expect(
        () => store.parseAnyToGroups(bad),
        throwsA(isA<FormatException>()),
        reason: 'ورودی: $bad',
      );
    }
  });

  test('پیام خطای فایل خراب شامل راهنماست', () {
    try {
      store.parseAnyToGroups('{oops');
      fail('باید خطا می‌داد');
    } on FormatException catch (e) {
      expect(e.message, contains('JSON'));
    }
  });

  // ─────────── عملیات واقعی روی استور ───────────

  test('افزودن گروه جدید کار می‌کند (باگ لیست غیرقابل‌تغییر)', () async {
    final before = store.groups.length;
    final g = await store.addGroup(name: 'گروه تست');
    expect(store.groups.length, before + 1);
    expect(store.activeGroup.id, g.id);
    await store.removeGroup(g.id);
    expect(store.groups.length, before);
  });

  test('importAsNewGroup از متن، گروه می‌سازد و درس می‌گذارد', () async {
    final before = store.groups.length;
    final g = await store.importAsNewGroup(
      '{"courses":[{"id":1,"name":"منطق","units":2,"sessions":[{"d":0,"s":8,"e":10}]}]}',
      name: 'ایمپورت تست',
    );
    expect(g.name, 'ایمپورت تست');
    expect(store.groups.length, before + 1);
    expect(store.activeGroup.courses.single.name, 'منطق');
    await store.removeGroup(g.id);
  });

  test('خطای فرمت‌نشدن: تک‌گروه فقط گروه فعال را عوض می‌کند', () async {
    final groupsBefore = store.groups.length;
    await store.importJson('{"courses":[{"id":1,"name":"یک درس تازه","units":2}]}');
    expect(store.groups.length, groupsBefore, reason: 'گروه‌های دیگر نباید حذف شوند');
    expect(store.activeGroup.courses.single.name, 'یک درس تازه');
  });

  test('importJson کل برنامه را جایگزین می‌کند', () async {
    final backup = store.exportJson();
    final n = await store.importJson(backup);
    expect(n, greaterThan(0));
  });

  test('JSON با شناسه‌های گروه تکراری اصلاح می‌شود', () async {
    final n = await store.importJson('''
{"groups":[
 {"id":"g1","name":"اول","courses":[{"id":1,"name":"الف","units":2}]},
 {"id":"g1","name":"دوم","courses":[{"id":1,"name":"ب","units":2}]}]}
''');
    expect(n, 2);
    expect(store.groups.length, 2);
    expect(store.groups.map((g) => g.id).toSet().length, 2, reason: 'شناسه‌ها یکتا شوند');
  });

  test('آرایهٔ خالی هیچ‌وقت برنامه را نابود نمی‌کند', () async {
    final before = store.exportJson();
    await expectLater(store.importJson('[]'), throwsA(isA<FormatException>()));
    expect(store.exportJson(), before, reason: 'برنامهٔ قبلی باید دست‌نخورده بماند');
  });
  test('JSON نامعتبر برنامهٔ فعلی را نابود نمی‌کند', () async {
    final before = store.exportJson();
    await expectLater(store.importJson('{"courses":[{"bad":true}]}'), throwsA(isA<FormatException>()));
    expect(store.exportJson(), before);
  });

  // ─────────── رفت‌وبرگشت کامل ───────────

  test('رفت‌وبرگشت: خروجی برنامه دقیقاً بازخوانی می‌شود', () async {
    final before = store.exportJson();
    await store.importJson(before);
    expect(store.exportJson(), before);
  });

  test('رفت‌وبرگشت با کد CP2', () async {
    final before = store.exportJson();
    final code = encodeBackupCode(before);
    await store.importJson(code);
    expect(store.exportJson(), before);
  });
}
