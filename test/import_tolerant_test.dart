import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';
import 'package:course_plan/jalali.dart';

/// ایمپورت نباید با تغییر جزئی قالب بشکنه؛ خروجی چت‌بات‌ها و فایل‌های
/// دست‌ساز اغلب کلیدها/نوع‌های متفاوتی دارند.
void main() {
  final store = ScheduleStore.instance;

  test('نسخهٔ خالی: هیچ گروهی از اول نیست و ایمپورت اولین گروه را می‌سازد', () async {
    // این تست فقط در حالت EMPTY_DEFAULT معنا دارد؛ در بیلد معمولی رد می‌شود.
    if (!kEmptyDefault) return;
    expect(store.groups, isEmpty);
    expect(store.activeGroup.id, '', reason: 'گروه مجازی');
    final g = await store.importAsNewGroup(
      '{"courses":[{"id":1,"name":"فلسفه","units":2,'
      '"sessions":[{"d":0,"s":8,"e":10}]}]}',
      name: 'ترم اول',
    );
    expect(g.name, 'ترم اول');
    expect(store.groups.length, 1);
    expect(store.activeGroup.courses.single.name, 'فلسفه');
  });

  test('آرایهٔ خالی نیست و ساختارهای رایج پذیرفته می‌شوند', () {
    expect(store.parseCoursesOnly('[]'), isEmpty);
  });

  test('کلیدهای کوتاه بومی برنامه', () {
    final text = '''
{"courses":[{"id":1,"name":"ریاضی","short":"ریاضی","units":3,
 "sessions":[{"d":0,"s":7.5,"e":9.5,"room":"۲۰۴","t":"نظری"}],
 "exam":{"jy":1405,"jm":10,"jd":29,"s":8,"e":10,"place":"سالن"}}]}
''';
    final list = store.parseCoursesOnly(text);
    expect(list.length, 1);
    expect(list.first.name, 'ریاضی');
    expect(list.first.units, 3);
    expect(list.first.sessions.single.room, '۲۰۴');
    expect(list.first.exam!.place, 'سالن');
  });

  test('کلیدهای بلند، ساعت متنی «۰۸:۰۰» و رنگ #RRGGBB', () {
    final text = '''
{"name":"ترم دوم","lessons":[
  {"id":"a","title":"آموزش والدین","teacher":"دکتر احمدی","credits":"۲","color":"#648C16",
   "classes":[{"day":"یکشنبه","start":"۰۸:۰۰","end":"10:00","location":"کلاس ۱۲","type":"عملی"}]}
]}
''';
    final list = store.parseCoursesOnly(text);
    expect(list.length, 1);
    final c = list.first;
    expect(c.name, 'آموزش والدین');
    expect(c.prof, 'دکتر احمدی');
    expect(c.units, 2);
    expect(c.colorValue, 0xFF648C16);
    final s = c.sessions.single;
    expect(s.day, 1, reason: 'یکشنبه = ۱');
    expect(s.start, 8.0);
    expect(s.end, 10.0);
    expect(s.room, 'کلاس ۱۲');
    expect(s.type, 'عملی');
  });

  test('آرایهٔ بدون پوشش و ارقام فارسی', () {
    final list = store.parseCoursesOnly('''
[
 {"id":1,"name":"فارسی","units":۲,"sessions":[{"day":2,"start":10,"end":12}]},
 {"id":2,"name":"علوم","units":3,"sessions":[{"day":3,"start":8,"end":9}]}
]
''');
    expect(list.length, 2);
    expect(list[0].units, 2);
    expect(list[0].id, 1);
    expect(list[0].colorValue, kCoursePalette[0]);
  });

  test('گروه کامل زیر کلید group', () {
    final text = '''
{"app":"course_plan","v":2,"group":{"id":"g9","name":"گروه ۲۵",
 "courses":[{"id":1,"name":"کارگاه","units":2,"sessions":[{"d":6,"s":7.5,"e":9.5}]}]}}
''';
    final list = store.parseCoursesOnly(text);
    expect(list.length, 1);
    expect(list.first.name, 'کارگاه');
  });

  test('کاماهای اضافه و مارک‌داون چت‌بات تحمل می‌شود', () {
    final text = '''
خب اینم برنامه‌ت:

```json
{"courses":[{"id":1,"name":"روان‌شناسی","units":2,
  "sessions":[{"d":1,"s":14,"e":16,"room":"۲۰۴"},]},]}
```
''';
    final list = store.parseCoursesOnly(text);
    expect(list.length, 1);
    expect(list.first.name, 'روان‌شناسی');
  });

  test('فایل خراب خطای فارسی می‌دهد نه استثنای خام', () {
    expect(() => store.parseCoursesOnly('{"courses": [ اینجا خرابه ]}'),
        throwsA(isA<FormatException>()));
    expect(() => store.parseCoursesOnly('{"foo": 1}'),
        throwsA(isA<FormatException>()));
  });

  test('زمان پایان نامعتبر اصلاح می‌شود، نه رد فایل', () {
    final list = store.parseCoursesOnly('''
{"courses":[{"id":1,"name":"ورزش","units":1,"sessions":[{"d":0,"s":10,"e":10}]}]}
''');
    expect(list.first.sessions.single.end, greaterThan(10));
  });

  test('رنگ نامعتبر به پالت پیش‌فرض برمی‌گردد', () {
    final list = store.parseCoursesOnly('''
{"courses":[{"id":1,"name":"هنر","units":2,"color":"آبی","sessions":[]}]}
''');
    expect(list.first.colorValue, kCoursePalette[0]);
  });

  test('تاریخ امتحان با کلیدهای y/m/d', () {
    final e = Exam.fromJson({'y': 1405, 'm': 11, 'd': 5, 'start': 9, 'end': 11});
    expect(e.date.y, 1405);
    expect(e.date.m, 11);
    expect(e.date.d, 5);
    expect(e.start, 9);
  });

  test('خروجی خود برنامه بدون تغییر برمی‌گردد (رفت و برگشت)', () {
    final c = Course(
      id: 1,
      name: 'آموزش والدین',
      short: 'والدین',
      units: 2,
      colorValue: kCoursePalette[3],
      sessions: const [Session(day: 1, start: 7.5, end: 9.5, room: '۲۰۴', type: 'نظری')],
      exam: Exam(date: JDate(1405, 10, 29), start: 8, end: 10, place: 'سالن'),
    );
    final back = Course.fromJson(c.toJson());
    expect(back.name, c.name);
    expect(back.units, c.units);
    expect(back.colorValue, c.colorValue);
    expect(back.sessions.single.start, 7.5);
    expect(back.exam!.date.d, 29);
  });
}
