import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';
import 'default_schedule.dart';
import 'models.dart';

/// منبع اصلی داده‌ها: گروه‌های درسی و درس‌هایشان روی گوشی ذخیره می‌شن و
/// قابل ویرایش هستن.
///
/// چند «گروه درسی» پشتیبانی می‌شود؛ هر گروه برنامهٔ مستقل خودش را دارد و
/// فقط [activeGroup] روی صفحهٔ اصلی، جدول هفتگی، امتحان‌ها و اعلان‌ها اثر
/// می‌گذارد.
class ScheduleStore extends ChangeNotifier {
  ScheduleStore._();
  static final ScheduleStore instance = ScheduleStore._();

  static const _key = 'groups_v2';
  static const _legacyKey = 'courses_v1';
  static const _activeKey = 'active_group_v1';

  SharedPreferences? _prefs;
  List<CourseGroup> _groups = _defaultGroups();
  String _activeId = 'g1';

  /// برنامهٔ پیش‌فرض: گروه ۲۴ و گروه ۲۵ در تاییدیهٔ انتخاب واحد.
  static List<CourseGroup> _defaultGroups() => [
        CourseGroup(id: 'g1', name: kDefaultGroupName, courses: List.of(kDefaultCourses)),
        CourseGroup(id: 'g2', name: kG25GroupName, courses: List.of(kG25Courses)),
      ];

  // ───────────── گروه‌ها ─────────────

  List<CourseGroup> get groups => List.unmodifiable(_groups);

  CourseGroup get activeGroup {
    for (final g in _groups) {
      if (g.id == _activeId) return g;
    }
    return _groups.first;
  }

  String get activeGroupId => activeGroup.id;

  /// درس‌های گروه فعال (سازگاری با کدهای قبلی).
  List<Course> get courses => List.unmodifiable(activeGroup.courses);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final decoded = _decodeGroups(raw);
        if (decoded.isNotEmpty) {
          _groups = decoded;
          final saved = _prefs!.getString(_activeKey);
          _activeId = _groups.any((g) => g.id == saved) ? saved! : _groups.first.id;
          await _migrateOldDefault();
          return;
        }
      } catch (_) {
        // به پیش‌فرض برمی‌گردیم
      }
    }
    // مهاجرت از نسخهٔ ۰.۰.۱ که فقط یک لیست درس ذخیره می‌کرد
    final legacy = _prefs!.getString(_legacyKey);
    if (legacy != null) {
      try {
        final list = _decodeCourses(legacy);
        if (list.isNotEmpty) {
          _groups = [
            CourseGroup(id: 'g1', name: kDefaultGroupName, courses: list),
            CourseGroup(id: 'g2', name: kG25GroupName, courses: List.of(kG25Courses)),
          ];
          _activeId = 'g1';
          await _commit();
          return;
        }
      } catch (_) {
        // بی‌خیال، پیش‌فرض می‌مونه
      }
    }
    _groups = _defaultGroups();
    _activeId = 'g1';
  }

  /// اگر دادهٔ قدیمی فقط یک «گروه اصلی» داشت، نامش را به
  /// «برنامه درسی گروه ۲۴» درمی‌آوریم و گروه ۲۵ را هم اضافه می‌کنیم.
  Future<void> _migrateOldDefault() async {
    if (_groups.length == 1 && _groups.first.name == 'گروه اصلی') {
      _groups[0] = _groups[0].copyWith(name: kDefaultGroupName);
      _groups.add(CourseGroup(id: 'g2', name: kG25GroupName, courses: List.of(kG25Courses)));
      if (_activeId != 'g1') _activeId = _groups.first.id;
      await _commit();
    }
  }

  Future<void> _commit() async {
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    await p.setString(_key, exportJson());
    await p.setString(_activeKey, _activeId);
  }

  /// کلید یکتای گروه بعدی.
  String _newGroupId() {
    var n = _groups.length + 1;
    while (_groups.any((g) => g.id == 'g$n')) {
      n++;
    }
    return 'g$n';
  }

  /// گروه فعال را با این شناسه عوض می‌کنه.
  Future<void> selectGroup(String id) async {
    if (!_groups.any((g) => g.id == id)) return;
    _activeId = id;
    await _commit();
  }

  /// گروه جدید می‌سازه و فعالش می‌کنه. نام خالی → «گروه N».
  ///
  /// [copyCoursesFromActive] اگر true باشه، درس‌های گروه فعلی کپی می‌شن تا
  /// کاربر مجبور نباشه همه رو از صفر وارد کنه.
  Future<CourseGroup> addGroup({
    String name = '',
    bool copyCoursesFromActive = false,
  }) async {
    final id = _newGroupId();
    final label = name.trim().isEmpty ? 'گروه ${fa(_groups.length + 1)}' : name.trim();
    final group = CourseGroup(
      id: id,
      name: label,
      courses: copyCoursesFromActive ? List.of(activeGroup.courses) : const [],
    );
    _groups.add(group);
    _activeId = id;
    await _commit();
    return group;
  }

  Future<void> renameGroup(String id, String name) async {
    final i = _groups.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _groups[i] = _groups[i].copyWith(name: trimmed);
    await _commit();
  }

  /// گروه رو پاک می‌کنه. آخرین گروه پاک نمی‌شه.
  Future<bool> removeGroup(String id) async {
    if (_groups.length <= 1) return false;
    final i = _groups.indexWhere((g) => g.id == id);
    if (i < 0) return false;
    _groups.removeAt(i);
    if (_activeId == id) _activeId = _groups.first.id;
    await _commit();
    return true;
  }

  Future<void> _setCourses(List<Course> list) async {
    final i = _groups.indexWhere((g) => g.id == _activeId);
    if (i < 0) return;
    _groups[i] = _groups[i].copyWith(courses: list);
    await _commit();
  }

  // ───────────── درس‌های گروه فعال ─────────────

  int nextId() => activeGroup.courses.fold<int>(0, (m, c) => c.id > m ? c.id : m) + 1;

  Course? byId(int id) {
    for (final c in activeGroup.courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> upsert(Course c) async {
    final list = List<Course>.of(activeGroup.courses);
    final i = list.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      list[i] = c;
    } else {
      list.add(c);
    }
    await _setCourses(list);
  }

  Future<void> remove(int id) async {
    final list = List<Course>.of(activeGroup.courses)..removeWhere((c) => c.id == id);
    await _setCourses(list);
  }

  Future<void> setMuted(int id, bool muted) async {
    final c = byId(id);
    if (c != null) await upsert(c.copyWith(muted: muted));
  }

  /// درس‌های گروه فعال را به برنامهٔ اولیهٔ همان گروه برمی‌گردونه.
  Future<void> resetToDefault() async {
    final list = _activeGroupIdToDefaultCourses();
    if (list == null) return;
    await _setCourses(List.of(list));
  }

  List<Course>? _activeGroupIdToDefaultCourses() {
    switch (_activeId) {
      case 'g1':
        return kDefaultCourses;
      case 'g2':
        return kG25Courses;
      default:
        return null;
    }
  }

  /// همهٔ گروه‌ها را پاک و فقط گروه‌های پیش‌فرض (۲۴ و ۲۵) را برمی‌گردونه.
  Future<void> resetAllGroups() async {
    _groups = _defaultGroups();
    _activeId = 'g1';
    await _commit();
  }

  // ───────────── پشتیبان‌گیری / اشتراک‌گذاری ─────────────

  String exportJson({bool pretty = false}) {
    final data = {
      'app': 'course_plan',
      'v': 2,
      'activeGroupId': _activeId,
      'groups': [for (final g in _groups) g.toJson()],
    };
    return pretty ? const JsonEncoder.withIndent('  ').convert(data) : jsonEncode(data);
  }

  /// پشتیبان فقط از گروه فعال (برای اشتراک‌گذاری یک برنامه).
  String exportActiveGroupJson({bool pretty = false}) {
    final data = {
      'app': 'course_plan',
      'v': 2,
      'group': activeGroup.toJson(),
    };
    return pretty ? const JsonEncoder.withIndent('  ').convert(data) : jsonEncode(data);
  }

  /// متن JSON رو جایگزین برنامهٔ فعلی می‌کنه. تعداد درس‌ها رو برمی‌گردونه.
  ///
  /// هم پشتیبان کامل (همهٔ گروه‌ها) و هم فایل تک‌گروهی و هم فرمت قدیمی
  /// نسخهٔ ۰.۰.۱ پذیرفته می‌شه.
  Future<int> importJson(String text) async {
    final data = jsonDecode(text.trim());

    // فرمت جدید: همهٔ گروه‌ها
    if (data is Map && data['groups'] is List) {
      final groups = _decodeGroups(text);
      if (groups.isEmpty) throw const FormatException('هیچ گروهی پیدا نشد');
      _groups = groups;
      final wanted = data['activeGroupId']?.toString();
      _activeId = _groups.any((g) => g.id == wanted) ? wanted! : _groups.first.id;
      await _commit();
      return _groups.fold<int>(0, (s, g) => s + g.courses.length);
    }

    // تک‌گروه یا فرمت قدیمی
    final list = _decodeCourses(text);
    if (list.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
    await _setCourses(list);
    return list.length;
  }

  List<Course> _decodeCourses(String raw) {
    final data = jsonDecode(raw);
    dynamic list = data is Map ? data['courses'] : data;
    if (list == null && data is Map && data['group'] is Map) {
      list = (data['group'] as Map)['courses'];
    }
    if (list is! List) throw const FormatException('فرمت نامعتبر');
    return [for (final c in list) Course.fromJson(Map<String, dynamic>.from(c as Map))];
  }

  List<CourseGroup> _decodeGroups(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map || data['groups'] is! List) {
      throw const FormatException('فرمت نامعتبر');
    }
    return [
      for (final g in (data['groups'] as List))
        CourseGroup.fromJson(Map<String, dynamic>.from(g as Map)),
    ];
  }

  // ───────────── پرس‌وجوها (روی گروه فعال) ─────────────

  List<SessionRef> get allSessions => sessionsOfGroup(activeGroup);

  List<SessionRef> sessionsOfGroup(CourseGroup group) => [
        for (final c in group.courses)
          for (var i = 0; i < c.sessions.length; i++) SessionRef(c, c.sessions[i], i),
      ];

  /// «کلاس بعدی» برای هر گروه دلخواه (صفحهٔ اصلی برای همهٔ گروه‌ها کارت می‌سازد).
  NextClass? findNextFor(CourseGroup group, DateTime now) {
    final today = dayIndexOf(now);
    final h = hourOf(now);
    for (var k = 0; k < 7; k++) {
      final day = (today + k) % 7;
      final list = sessionsOfGroup(group).where((s) => s.session.day == day).toList();
      list.sort((a, b) => a.session.start.compareTo(b.session.start));
      final visible = list.where((s) => k > 0 || s.session.end > h).toList();
      if (visible.isNotEmpty) {
        final first = visible.first;
        return NextClass(first, k, k == 0 && first.session.start <= h);
      }
    }
    return null;
  }

  List<SessionRef> sessionsOn(int day) {
    final list = allSessions.where((s) => s.session.day == day).toList();
    list.sort((a, b) => a.session.start.compareTo(b.session.start));
    return list;
  }

  NextClass? findNext(DateTime now) => findNextFor(activeGroup, now);

  List<Course> examsSorted() {
    final list = activeGroup.courses.where((c) => c.exam != null).toList();
    list.sort((a, b) => a.exam!.gregorian.compareTo(b.exam!.gregorian));
    return list;
  }

  int get totalUnits => activeGroup.totalUnits;

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
    return activeGroup.courses
        .where((x) => x.id != c.id && x.exam != null && x.exam!.date == e.date)
        .toList();
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
