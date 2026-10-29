import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/backup_code.dart';
import 'package:course_plan/data/models.dart';
import 'package:course_plan/data/schedule_store.dart';

/// این فایل‌ها خروجی واقعی یک چت‌بات برای «برنامهٔ انتخاب واحد» یک دانشجوی
/// دیگر است. هر تغییر در پارسر نباید این دو را بشکند.
void main() {
  final store = ScheduleStore.instance;
  final jsonText = File('test/fixtures/friend_plan.json').readAsStringSync();
  final compactText = File('test/fixtures/friend_plan.txt').readAsStringSync();

  test('JSON واقعی چت‌بات: ۹ درس، ۱۴ جلسه، ۷ امتحان', () {
    final r = store.parseAnyToGroups(jsonText);
    final courses = r.groups.first.courses;

    expect(courses.length, 9);
    expect(courses.fold<int>(0, (s, c) => s + c.sessions.length), 14);
    expect(courses.where((c) => c.exam != null).length, 7);
  });

  test('JSON واقعی: نام گروه از plan.name خوانده می‌شود', () {
    expect(store.parseAnyToGroups(jsonText).suggestedName, 'ترم اول ۱۴۰۵');
  });

  test('JSON واقعی: color کوچک = شمارهٔ پالت، نه رنگ شفاف', () {
    final courses = store.parseAnyToGroups(jsonText).groups.first.courses;
    // خروجی چت‌بات color=0..8 می‌دهد؛ هر کدام باید یک رنگ کامل از پالت باشد.
    for (final c in courses) {
      expect(c.colorValue, greaterThan(0xFF000000),
          reason: 'درس «${c.name}» رنگ شفاف گرفته');
      expect(kCoursePalette.contains(c.colorValue), isTrue,
          reason: 'درس «${c.name}» رنگش در پالت نیست: ${c.colorValue.toRadixString(16)}');
    }
    expect(courses[1].colorValue, kCoursePalette[1]);
    expect(courses[8].colorValue, kCoursePalette[8]);
  });

  test('JSON واقعی: جزئیات یک درس دقیق است', () {
    final c = store.parseAnyToGroups(jsonText).groups.first.courses[0];
    expect(c.name, 'فنون راهنمایی و مشاوره دوره ابتدایی');
    expect(c.short, 'فنون راهنمایی و مشاوره');
    expect(c.prof, 'صالح غیاثی‌نژاد');
    expect(c.kind, 'تخصصی');
    expect(c.units, 2);
    expect(c.sessions.length, 2);
    expect(c.sessions[0].day, 0);
    expect(c.sessions[0].start, 15.5);
    expect(c.sessions[0].end, 17.5);
    expect(c.sessions[1].day, 5);
    expect(c.sessions[1].start, 19.5);
    expect(c.sessions[1].end, 20.5);
    expect(c.exam!.date.y, 1405);
    expect(c.exam!.date.m, 10);
    expect(c.exam!.date.d, 30);
    expect(c.exam!.start, 8.0);
    expect(c.exam!.end, 10.0);
  });

  test('JSON واقعی: امتحان با کلیدهای year/month/day', () {
    final c = store.parseAnyToGroups(jsonText).groups.first.courses[3];
    expect(c.name, 'مشکلات یادگیری خاص');
    expect(c.exam!.date.d, 21);
    expect(c.exam!.place, '');
  });

  test('JSON واقعی: درس بدون امتحان (کارگاه/کارورزی)', () {
    final courses = store.parseAnyToGroups(jsonText).groups.first.courses;
    expect(courses[2].exam, isNull);
    expect(courses[8].exam, isNull);
    expect(courses[8].kind, 'کارورزی');
    expect(courses[8].sessions.single.start, 7.5);
    expect(courses[8].sessions.single.end, 15.5);
  });

  test('متن خطی واقعی چت‌بات: همان ۹ درس و ۱۴ جلسه', () {
    expect(isCompactPlanText(compactText), isTrue);
    final p = parseCompactPlan(compactText);
    expect(p.name, 'ترم اول ۱۴۰۵');
    expect(p.courses.length, 9);
    expect(p.courses.fold<int>(0, (s, c) => s + c.sessions.length), 14);
    expect(p.courses.where((c) => c.exam != null).length, 7);
  });

  test('متن خطی و JSON یک نتیجه می‌دهند', () {
    final fromJson = store.parseAnyToGroups(jsonText).groups.first.courses;
    final fromText = parseCompactPlan(compactText).courses;

    expect(fromText.length, fromJson.length);
    for (var i = 0; i < fromJson.length; i++) {
      expect(fromText[i].name, fromJson[i].name, reason: 'درس ${i + 1}');
      expect(fromText[i].units, fromJson[i].units, reason: 'واحد درس ${i + 1}');
      expect(fromText[i].sessions.length, fromJson[i].sessions.length,
          reason: 'تعداد جلسهٔ «${fromJson[i].name}»');
      expect(fromText[i].exam?.date.d, fromJson[i].exam?.date.d,
          reason: 'روز امتحان «${fromJson[i].name}»');
      for (var j = 0; j < fromJson[i].sessions.length; j++) {
        expect(fromText[i].sessions[j].day, fromJson[i].sessions[j].day);
        expect(fromText[i].sessions[j].start, fromJson[i].sessions[j].start);
        expect(fromText[i].sessions[j].end, fromJson[i].sessions[j].end);
      }
    }
  });

  test('ایمپورت واقعی به‌عنوان گروه جدید کار می‌کند (JSON)', () async {
    final before = store.groups.length;
    final g = await store.importAsNewGroup(jsonText, name: 'ترم دوست');
    expect(g.name, 'ترم دوست');
    expect(store.groups.length, before + 1);
    expect(store.activeGroup.courses.length, 9);
    expect(store.activeGroup.totalUnits, 17);
    await store.removeGroup(g.id);
  });

  test('ایمپورت واقعی به‌عنوان گروه جدید کار می‌کند (متن)', () async {
    final before = store.groups.length;
    final g = await store.importAsNewGroup(compactText, name: 'ترم دوست متن');
    expect(g.name, 'ترم دوست متن');
    expect(store.groups.length, before + 1);
    expect(store.activeGroup.courses.length, 9);
    await store.removeGroup(g.id);
  });

  test('ایمپورت بدون نام، نام گروه را از فایل می‌گیرد', () async {
    final g = await store.importAsNewGroup(jsonText);
    expect(g.name, 'ترم اول ۱۴۰۵');
    await store.removeGroup(g.id);
  });
}
