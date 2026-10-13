import 'package:flutter_test/flutter_test.dart';
import 'package:group24/data/schedule_store.dart';
import 'package:group24/jalali.dart';
import 'package:group24/utils.dart';

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
}
