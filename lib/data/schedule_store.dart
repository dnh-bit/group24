import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';
import 'default_schedule.dart';
import 'models.dart';

/// منبع اصلی داده‌ها: درس‌ها روی گوشی ذخیره می‌شن و قابل ویرایش هستن.
class ScheduleStore extends ChangeNotifier {
  ScheduleStore._();
  static final ScheduleStore instance = ScheduleStore._();

  static const _key = 'courses_v1';
  SharedPreferences? _prefs;
  List<Course> _courses = List.of(kDefaultCourses);

  List<Course> get courses => List.unmodifiable(_courses);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _courses = _decode(raw);
      } catch (_) {
        _courses = List.of(kDefaultCourses);
      }
    }
  }

  Future<void> _commit() async {
    notifyListeners();
    await _prefs?.setString(_key, exportJson());
  }

  int nextId() => _courses.fold<int>(0, (m, c) => c.id > m ? c.id : m) + 1;

  Course? byId(int id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> upsert(Course c) async {
    final i = _courses.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _courses[i] = c;
    } else {
      _courses.add(c);
    }
    await _commit();
  }

  Future<void> remove(int id) async {
    _courses.removeWhere((c) => c.id == id);
    await _commit();
  }

  Future<void> setMuted(int id, bool muted) async {
    final c = byId(id);
    if (c != null) await upsert(c.copyWith(muted: muted));
  }

  Future<void> resetToDefault() async {
    _courses = List.of(kDefaultCourses);
    await _commit();
  }

  // ───────────── پشتیبان‌گیری / اشتراک‌گذاری ─────────────

  String exportJson({bool pretty = false}) {
    final data = {
      'app': 'group24',
      'v': 1,
      'courses': [for (final c in _courses) c.toJson()],
    };
    return pretty ? const JsonEncoder.withIndent('  ').convert(data) : jsonEncode(data);
  }

  /// متن JSON رو جایگزین برنامهٔ فعلی می‌کنه. تعداد درس‌ها رو برمی‌گردونه.
  Future<int> importJson(String text) async {
    final list = _decode(text.trim());
    if (list.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
    _courses = list;
    await _commit();
    return list.length;
  }

  List<Course> _decode(String raw) {
    final data = jsonDecode(raw);
    final list = data is Map ? data['courses'] : data;
    if (list is! List) throw const FormatException('فرمت نامعتبر');
    return [for (final c in list) Course.fromJson(Map<String, dynamic>.from(c as Map))];
  }

  // ───────────── پرس‌وجوها ─────────────

  List<SessionRef> get allSessions => [
        for (final c in _courses)
          for (var i = 0; i < c.sessions.length; i++) SessionRef(c, c.sessions[i], i),
      ];

  List<SessionRef> sessionsOn(int day) {
    final list = allSessions.where((s) => s.session.day == day).toList();
    list.sort((a, b) => a.session.start.compareTo(b.session.start));
    return list;
  }

  NextClass? findNext(DateTime now) {
    final today = dayIndexOf(now);
    final h = hourOf(now);
    for (var k = 0; k < 7; k++) {
      final day = (today + k) % 7;
      final list = sessionsOn(day).where((s) => k > 0 || s.session.end > h).toList();
      if (list.isNotEmpty) {
        final first = list.first;
        return NextClass(first, k, k == 0 && first.session.start <= h);
      }
    }
    return null;
  }

  List<Course> examsSorted() {
    final list = _courses.where((c) => c.exam != null).toList();
    list.sort((a, b) => a.exam!.gregorian.compareTo(b.exam!.gregorian));
    return list;
  }

  int get totalUnits => _courses.fold(0, (s, c) => s + c.units);

  double get weeklyHours => allSessions.fold(0.0, (s, r) => s + r.session.length);

  /// تداخل کلاس‌ها
  List<Conflict> conflicts() {
    final all = allSessions;
    final out = <Conflict>[];
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        if (all[i].session.overlaps(all[j].session)) out.add(Conflict(all[i], all[j]));
      }
    }
    return out;
  }

  /// درس‌هایی که با این جلسه تداخل دارن (به‌جز خود درس)
  List<Course> conflictsWith(Session s, {int? exceptCourseId}) {
    final out = <Course>[];
    for (final r in allSessions) {
      if (r.course.id == exceptCourseId) continue;
      if (r.session.overlaps(s) && !out.contains(r.course)) out.add(r.course);
    }
    return out;
  }

  /// امتحان‌هایی که یک روز دارن
  List<Course> examsSameDay(Course c) {
    final e = c.exam;
    if (e == null) return const [];
    return _courses.where((x) => x.id != c.id && x.exam != null && x.exam!.date == e.date).toList();
  }

  /// بازهٔ ساعت جدول هفتگی
  (double, double) get gridRange {
    var lo = 7.5, hi = 20.5;
    for (final r in allSessions) {
      if (r.session.start < lo) lo = r.session.start.floorToDouble();
      if (r.session.end > hi) hi = r.session.end.ceilToDouble();
    }
    return (lo, hi);
  }
}
