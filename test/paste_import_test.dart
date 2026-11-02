import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/data/schedule_store.dart';

/// پیست متن در صفحهٔ دستیار هوشمند: هر سه قالبی که کاربر از چت‌بات می‌گیرد
/// باید در همان صفحه پذیرفته شود، و متن خراب نباید برنامهٔ فعلی را دست بزند.
void main() {
  final store = ScheduleStore.instance;
  final jsonText = File('test/fixtures/friend_plan.json').readAsStringSync();
  final compactText = File('test/fixtures/friend_plan.txt').readAsStringSync();

  group('پیش‌نمایش پیست (بدون تغییر داده)', () {
    test('فرمت PLAN| پیش‌نمایش درست می‌دهد', () {
      final p = store.parseAnyToGroups(compactText);
      final cs = p.groups.first.courses;
      expect(cs.length, 9);
      expect(cs.fold<int>(0, (s, c) => s + c.sessions.length), 14);
      expect(cs.where((c) => c.exam != null).length, 7);
      expect(cs.fold<int>(0, (s, c) => s + c.units), 17);
    });

    test('فرمت JSON همان نتیجه را می‌دهد', () {
      final p = store.parseAnyToGroups(jsonText);
      final cs = p.groups.first.courses;
      expect(cs.length, 9);
      expect(cs.fold<int>(0, (s, c) => s + c.sessions.length), 14);
      expect(cs.fold<int>(0, (s, c) => s + c.units), 17);
      expect(p.suggestedName, 'ترم اول ۱۴۰۵');
    });

    test('parseAnyToGroups داده را تغییر نمی‌دهد', () {
      final before = store.groups.length;
      store.parseAnyToGroups(jsonText);
      store.parseAnyToGroups(compactText);
      expect(store.groups.length, before, reason: 'پیش‌نمایش نباید گروه بسازد');
    });
  });

  group('متن خراب', () {
    test('متن خالی خطا می‌دهد', () {
      expect(() => store.parseAnyToGroups(''), throwsA(isA<Exception>()));
    });

    test('متن بی‌ربط خطا می‌دهد', () {
      expect(() => store.parseAnyToGroups('سلام خوبی'), throwsA(isA<Exception>()));
    });

    test('JSON بدون درس خطا می‌دهد و برنامه را پاک نمی‌کند', () {
      final before = store.groups.length;
      expect(() => store.parseAnyToGroups('{"courses":[{"bad":true}]}'),
          throwsA(isA<Exception>()));
      expect(store.groups.length, before);
    });
  });

  group('ایمپورت به‌عنوان گروه جدید', () {
    test('از متن PLAN| یک گروه اضافه می‌کند', () async {
      final before = store.groups.length;
      final g = await store.importAsNewGroup(compactText);
      expect(store.groups.length, before + 1);
      expect(g.courses.length, 9);
      await store.removeGroup(g.id);
    });

    test('از JSON یک گروه با نام درست اضافه می‌کند', () async {
      final before = store.groups.length;
      final g = await store.importAsNewGroup(jsonText);
      expect(store.groups.length, before + 1);
      expect(g.name, 'ترم اول ۱۴۰۵');
      expect(store.activeGroup.id, g.id);
      await store.removeGroup(g.id);
    });

    test('منطقه‌ای که متن دارد هم بی‌خطر است (فقط یک بار اضافه)', () async {
      final before = store.groups.length;
      final g = await store.importAsNewGroup(compactText);
      expect(store.groups.length, before + 1);
      // ایمپورت دوباره یک گروه دیگر می‌سازد، نه اینکه روی قبلی بیفتد
      final g2 = await store.importAsNewGroup(compactText);
      expect(store.groups.length, before + 2);
      expect(g2.id, isNot(g.id));
      await store.removeGroup(g.id);
      await store.removeGroup(g2.id);
    });
  });
}
