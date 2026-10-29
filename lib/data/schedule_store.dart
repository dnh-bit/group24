import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';
import '../services/settings_service.dart';
import 'backup_code.dart';
import 'default_schedule.dart';
import 'models.dart';

/// نسخهٔ «خالی»: با --dart-define=EMPTY_DEFAULT=true ساخته می‌شه؛
/// بدون برنامه‌های پیش‌فرض گروه ۲۴ و ۲۵ — برای استفادهٔ همهٔ دانشگاه‌ها.
const bool kEmptyDefault = bool.fromEnvironment('EMPTY_DEFAULT');

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
  /// در نسخهٔ خالی (EMPTY_DEFAULT) هیچ گروهی از اول وجود نداره.
  static List<CourseGroup> _defaultGroups() {
    if (kEmptyDefault) return const [];
    return [
      CourseGroup(id: 'g1', name: kDefaultGroupName, courses: List.of(kDefaultCourses)),
      CourseGroup(id: 'g2', name: kG25GroupName, courses: List.of(kG25Courses)),
    ];
  }

  /// گروه مجازی وقتی هیچ گروهی وجود نداره — فقط برای اینکه UI نشکنه.
  static const CourseGroup kNoGroup = CourseGroup(id: '', name: 'بدون گروه', courses: []);

  // ───────────── گروه‌ها ─────────────

  List<CourseGroup> get groups => List.unmodifiable(_groups);

  CourseGroup get activeGroup {
    for (final g in _groups) {
      if (g.id == _activeId) return g;
    }
    if (_groups.isEmpty) return kNoGroup;
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

  /// فقط پارس می‌کند و هیچ داده‌ای را تغییر نمی‌دهد (تست/پیش‌نمایش).
  List<Course> parseCoursesOnly(String text) {
    final decoded = tryDecodeBackupCode(text);
    if (decoded != null) text = decoded;
    if (isCompactPlanText(text)) return parseCompactPlan(text).courses;

    final data = _safeJson(text);
    if (data == null) {
      throw const FormatException('فایل JSON سالم نیست (ساختار شکسته یا ناقصه)');
    }
    // آرایهٔ خالی = برنامهٔ بدون درس (در ایمپورت رد می‌شود، در پارس مجاز است)
    if (data is List && data.isEmpty) return const [];

    final map = data is Map
        ? <String, dynamic>{
            for (final e in data.entries) e.key.toString().toLowerCase(): e.value,
            for (final e in data.entries) e.key.toString(): e.value,
          }
        : null;

    if (map != null && (map['groups'] is List || map['گروه‌ها'] is List)) {
      final groups = _decodeGroups(text);
      return groups.isEmpty ? const [] : groups.first.courses;
    }
    if (map != null && map['group'] is Map) {
      return CourseGroup.fromJson(Map<String, dynamic>.from(map['group'] as Map)).courses;
    }
    return _decodeCourses(text);
  }

  /// JSON را می‌خواند؛ اگر نشد null برمی‌گرداند (بدون پرتاب استثنای خام).
  dynamic _safeJson(String raw) {
    var s = extractJson(raw);
    try {
      return jsonDecode(s);
    } catch (_) {
      // تلاش دوم: پاک کردن کاماهای اضافه و نقل‌قول‌های فارسی
      s = s
          .replaceAll(RegExp(r',\s*([}\]])'), r'$1')
          .replaceAll('“', '"')
          .replaceAll('”', '"');
      try {
        return jsonDecode(s);
      } catch (_) {
        return null;
      }
    }
  }

  /// متن JSON رو جایگزین برنامهٔ فعلی می‌کنه. تعداد درس‌ها رو برمی‌گردونه.
  ///
  /// هم پشتیبان کامل (همهٔ گروه‌ها) و هم فایل تک‌گروهی و هم فرمت قدیمی
  /// نسخهٔ ۰.۰.۱ پذیرفته می‌شه. قبل از جایگزینی همه‌چیز اعتبارسنجی می‌شه تا
  /// فایل نیم‌باطل، نیمهٔ درست برنامه رو نابود نکنه.
  Future<int> importJson(String text) async {
    // کد کوتاه پشتیبان (CP2:) → JSON اصلی
    final decoded = tryDecodeBackupCode(text);
    if (decoded != null) text = decoded;

    // فرمت خطی کوتاه (خروجی چت‌بات)
    if (isCompactPlanText(text)) {
      final p = parseCompactPlan(text);
      _validateCourses(p.courses, p.name.isEmpty ? 'درس' : p.name);
      await _setCourses(p.courses);
      return p.courses.length;
    }

    final data = jsonDecode(extractJson(text)); // BOM ویندوزی و بلوک کد چت‌بات‌ها پاک می‌شه

    // فرمت جدید: همهٔ گروه‌ها
    if (data is Map && data['groups'] is List) {
      final groups = _decodeGroups(text);
      _validateGroups(groups);
      if (groups.isEmpty) throw const FormatException('هیچ گروهی پیدا نشد');
      _groups = groups;
      final wanted = data['activeGroupId']?.toString();
      _activeId = _groups.any((g) => g.id == wanted) ? wanted! : _groups.first.id;
      await _commit();
      return _groups.fold<int>(0, (s, g) => s + g.courses.length);
    }

    // تک‌گروه یا فرمت قدیمی
    final list = _decodeCourses(text);
    _validateCourses(list, 'درس');
    if (list.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
    await _setCourses(list);
    return list.length;
  }

  void _validateGroups(List<CourseGroup> groups) {
    if (groups.isEmpty) throw const FormatException('هیچ گروهی پیدا نشد');
    for (final g in groups) {
      if (g.name.trim().isEmpty) {
        throw const FormatException('یکی از گروه‌ها بدون نام است');
      }
      _validateCourses(g.courses, g.name);
    }
  }

  void _validateCourses(List<Course> courses, String scope) {
    final seenIds = <int>{};
    for (final c in courses) {
      if (c.name.trim().isEmpty) {
        throw FormatException('در «$scope» درسی بدون نام هست');
      }
      if (!seenIds.add(c.id)) {
        throw FormatException('در «$scope» شناسهٔ تکراری داره (id ${c.id})');
      }
      if (c.units < 0 || c.units > 30) {
        throw FormatException('در «$scope» تعداد واحد درس «${c.name}» نامعتبره');
      }
      for (final s in c.sessions) {
        if (s.day < 0 || s.day > 6) {
          throw FormatException(
              'در «$scope» جلسه‌ای از درس «${c.name}» روز معتبری نداره (روز ${s.day})');
        }
        if (s.start < 0 || s.start > 24 || s.end <= s.start || s.end > 24) {
          throw FormatException(
              'در «$scope» ساعت جلسهٔ درس «${c.name}» (${kDayNames[s.day]}) نامعتبره');
        }
      }
    }
  }

  List<Course> _decodeCourses(String raw) {
    final data = jsonDecode(extractJson(raw));
    dynamic list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['courses'] ?? data['lessons'] ?? data['درس‌ها'];
      if (list == null && data['group'] is Map) {
        final g = data['group'] as Map;
        list = g['courses'] ?? g['lessons'] ?? g['درس‌ها'];
      }
      // تک‌گروه با کلید‌های فارسی («درس‌ها») یا آرایهٔ نام‌دار
      if (list == null) {
        for (final v in data.values) {
          if (v is List && v.isNotEmpty && v.first is Map &&
              ((v.first as Map).containsKey('name') || (v.first as Map).containsKey('نام'))) {
            list = v;
            break;
          }
        }
      }
    }
    if (list is! List) {
      throw const FormatException('فایل هیچ فهرست درسی نداره (کلید courses یا درس‌ها لازمه)');
    }
    final out = <Course>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final c = Course.fromJson(Map<String, dynamic>.from(item));
      out.add(c.id > 0 ? c : c.copyWith(id: i + 1));
    }
    if (out.isEmpty) throw const FormatException('هیچ درسی توی فایل پیدا نشد');
    return out;
  }

  List<CourseGroup> _decodeGroups(String raw) {
    final data = jsonDecode(extractJson(raw));
    if (data is! Map) throw const FormatException('فرمت نامعتبر');
    final rawGroups = data['groups'] ?? data['گروه‌ها'];
    if (rawGroups is! List) {
      // ممکنه مستقیم آرایهٔ گروه‌ها باشه یا یک گروه تنها زیر «group»
      if (data['group'] is Map) {
        return [CourseGroup.fromJson(Map<String, dynamic>.from(data['group'] as Map))];
      }
      throw const FormatException('فایل هیچ گروهی نداره (کلید groups لازمه)');
    }
    return [
      for (final g in rawGroups)
        if (g is Map) CourseGroup.fromJson(Map<String, dynamic>.from(g)),
    ];
  }

  /// خروجی هوش مصنوعی یا فایل تک‌گروهی را به‌عنوان «گروه جدید» اضافه می‌کند
  /// و برنامهٔ فعلی را دست‌نخورده نگه می‌دارد. گروه تازه فعال می‌شود.
  ///
  /// [name] خالی باشد از نام فایل JSON (کلید name) یا پیش‌فرض استفاده می‌شود.
  Future<CourseGroup> importAsNewGroup(String text, {String name = ''}) async {
    final decoded = tryDecodeBackupCode(text);
    if (decoded != null) text = decoded;

    // فرمت خطی کوتاه (خروجی چت‌بات)
    if (isCompactPlanText(text)) {
      final p = parseCompactPlan(text);
      _validateCourses(p.courses, p.name.isEmpty ? 'درس' : p.name);
      final label = name.trim().isNotEmpty ? name.trim() : p.name;
      final group = await addGroup(name: label);
      await _setCourses(p.courses);
      return group.copyWith(courses: p.courses);
    }

    final data = _safeJson(text);
    if (data == null) {
      throw const FormatException('فایل JSON سالم نیست (ساختار شکسته یا ناقصه)');
    }
    // کلیدهای با حروف بزرگ/کوچک یا فارسی
    Map<String, dynamic>? map;
    if (data is Map) {
      map = {for (final e in data.entries) e.key.toString().toLowerCase(): e.value};
      for (final e in data.entries) {
        map.putIfAbsent(e.key.toString(), () => e.value);
      }
    }

    List<Course> courses;
    String suggested;

    // فایل کاملِ همهٔ گروه‌ها
    if (map != null && (map['groups'] is List || map['گروه‌ها'] is List)) {
      final groups = _decodeGroups(text);
      _validateGroups(groups);
      courses = groups.first.courses;
      suggested = groups.first.name;
    } else if (map != null && map['group'] is Map) {
      final g = CourseGroup.fromJson(Map<String, dynamic>.from(map['group'] as Map));
      _validateCourses(g.courses, g.name);
      courses = g.courses;
      suggested = g.name;
    } else if (map != null && map['courses'] is List) {
      courses = _decodeCourses(text);
      _validateCourses(courses, 'درس');
      suggested = '';
    } else if (data is List &&
        data.isNotEmpty &&
        data.every((e) => e is List || (e is Map && (e['courses'] is List || e['lessons'] is List)))) {
      // آرایهٔ گروه‌ها بدون پوشش {groups: …}
      final g = CourseGroup.fromJson(Map<String, dynamic>.from(data.first as Map));
      _validateCourses(g.courses, g.name);
      courses = g.courses;
      suggested = g.name;
    } else {
      courses = _decodeCourses(text);
      _validateCourses(courses, 'درس');
      suggested = '';
    }
    if (courses.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');

    final label = name.trim().isNotEmpty ? name.trim() : suggested;
    final group = await addGroup(name: label);
    await _setCourses(courses);
    return group.copyWith(courses: courses);
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
    final cancelOneHour = SettingsService.instance.settings.cancelOneHourClasses;
    for (var k = 0; k < 7; k++) {
      final day = (today + k) % 7;
      // اگر لغو کلاس‌های تک‌ساعته فعال باشد، از «کلاس بعدی» حذف می‌شوند
      final list = sessionsOfGroup(group)
          .where((s) => s.session.day == day && !(cancelOneHour && s.session.isOneHour))
          .toList();
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

  /// گروهی که اعلان‌ها به برنامهٔ اون می‌رفته — انتخاب کاربر در تنظیمات.
  /// اگر هنوز انتخاب نشده یا گروهش پاک شده، گروه فعال.
  CourseGroup groupForNotifications() {
    final want = SettingsService.instance.settings.notifGroupId;
    for (final g in _groups) {
      if (g.id == want) return g;
    }
    return activeGroup;
  }

  int get totalUnits => activeGroup.totalUnits;

  double get weeklyHours => allSessions.fold(0.0, (s, r) => s + r.session.length);

  /// تداخل کلاس‌ها (اگر لغو کلاس‌های تک‌ساعته فعال باشد، حساب نمی‌شن)
  List<Conflict> conflicts() {
    final cancelOneHour = SettingsService.instance.settings.cancelOneHourClasses;
    final all = allSessions.where((r) => !(cancelOneHour && r.session.isOneHour)).toList();
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
