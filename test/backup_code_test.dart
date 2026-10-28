import 'package:flutter_test/flutter_test.dart';
import 'package:course_plan/data/backup_code.dart';
import 'package:course_plan/data/schedule_store.dart';

void main() {
  test('کد کوتاه پشتیبان رفت‌وبرگشت دارد', () {
    const json = '{"app":"course_plan","v":2,"groups":[{"id":"g1","name":"برنامهٔ تست ۲۴","courses":[]}]}';
    final code = encodeBackupCode(json);
    expect(code.startsWith('CP2:'), isTrue);
    // کوتاه‌تر از JSON مرتب است
    expect(code.length, lessThan(json.length + 20));
    expect(tryDecodeBackupCode(code), json);
  });

  test('کد کوتاه با فاصله و خطِ شکستهٔ چت هم باز می‌شود', () {
    const json = '{"a":"متن فارسی"}';
    final code = encodeBackupCode(json);
    final broken = code.replaceAll('CP2:', 'CP2:\n ').replaceAllMapped(
        RegExp(r'(.{40})'), (m) => '${m[1]}\n');
    expect(tryDecodeBackupCode(broken), json);
  });

  test('متن معمولی کد پشتیبان شناخته نمی‌شود', () {
    expect(tryDecodeBackupCode('{"a":1}'), isNull);
    expect(tryDecodeBackupCode('سلام'), isNull);
  });

  final compact = '''
PLAN|name=ترم تست
c1|تاریخ فرهنگ و تمدن|تاریخ تمدن|علی یزدانی|معارف|2|0
s|3|15.5|17.5|کلاس ۲۰۴|نظری
x|1405|10|29|8|10|
c2|آسیب‌شناسی اجتماعی|آسیب‌شناسی|بلوردی|تخصصی|2|2
s|3|17.5|19.5|کلاس ۴۰۶|نظری
''';

  test('فرمت خطی کوتاه پارس می‌شود', () {
    expect(isCompactPlanText(compact), isTrue);
    expect(isCompactPlanText('{"a":1}'), isFalse);
    expect(isCompactPlanText('```json\n{"a":1}\n```'), isFalse);

    final p = parseCompactPlan(compact);
    expect(p.name, 'ترم تست');
    expect(p.courses.length, 2);
    final c1 = p.courses[0];
    expect(c1.id, 1);
    expect(c1.name, 'تاریخ فرهنگ و تمدن');
    expect(c1.kind, 'معارف');
    expect(c1.units, 2);
    expect(c1.sessions.single.day, 3);
    expect(c1.sessions.single.start, 15.5);
    expect(c1.sessions.single.room, 'کلاس ۲۰۴');
    expect(c1.exam!.date.y, 1405);
    expect(c1.exam!.date.m, 10);
    expect(c1.exam!.date.d, 29);
    expect(c1.exam!.start, 8.0);
    final c2 = p.courses[1];
    expect(c2.exam, isNull);
    expect(c2.sessions.single.end, 19.5);
  });

  test('فرمت خطی داخل بلوک کد هم پارس می‌شود', () {
    final fenced = 'خب اینم برنامه:\n```\n$compact```\nموفق باشی!';
    expect(isCompactPlanText(fenced), isTrue);
    final p = parseCompactPlan(fenced);
    expect(p.courses.length, 2);
  });

  test('ساعت نامعتبر در فرمت خطی رد می‌شود', () {
    final bad = 'PLAN|name=x\nc1|درس|درس|استاد|تخصصی|2|0\ns|0|10|9|کلاس|نظری\n';
    expect(() => parseCompactPlan(bad), throwsFormatException);
  });

  test('import با فرمت خطی، برنامهٔ گروه فعال را جایگزین می‌کند', () async {
    final store = ScheduleStore.instance;
    final n = await store.importJson(compact);
    expect(n, 2);
    expect(store.courses.first.name, 'تاریخ فرهنگ و تمدن');
  });

  test('import با کد کوتاه پشتیبان کار می‌کند', () async {
    final store = ScheduleStore.instance;
    final code = encodeBackupCode(store.exportJson());
    final n = await store.importJson(code);
    expect(n, greaterThan(0));
  });
}
