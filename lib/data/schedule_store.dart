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
  String _activeId = _defaultGroups().isEmpty ? '' : 'g1';

  /// برنامهٔ پیش‌فرض: گروه ۲۴ و گروه ۲۵ در تاییدیهٔ انتخاب واحد.
  /// در نسخهٔ خالی (EMPTY_DEFAULT) هیچ گروهی از اول وجود نداره.
  ///
  /// توجه: لیست باید قابل تغییر (growable) باشد — `const []` غیرقابل‌تغییر است
  /// و `addGroup` با خطای «Cannot add to an unmodifiable list» می‌شکست.
  static List<CourseGroup> _defaultGroups() {
    if (kEmptyDefault) return <CourseGroup>[];
    return <CourseGroup>[
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
            // در نسخهٔ خالی نباید گروه ۲۵ تزریق شود
            if (!kEmptyDefault)
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
    _activeId = _groups.isEmpty ? '' : _groups.first.id;
  }

  /// اگر دادهٔ قدیمی فقط یک «گروه اصلی» داشت، نامش را به
  /// «برنامه درسی گروه ۲۴» درمی‌آوریم و گروه ۲۵ را هم اضافه می‌کنیم.
  Future<void> _migrateOldDefault() async {
    if (kEmptyDefault) return; // نسخهٔ خالی هیچ گروه پیش‌فرضی نمی‌سازد
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
    // شناسه‌های تکراری/خالی را یکتا کن — فایل چت‌بات اغلب id تکراری دارد و
    // بعداً ویرایش/حذف درس را خراب می‌کند.
    final seen = <int>{};
    final safe = <Course>[];
    for (var j = 0; j < list.length; j++) {
      var c = list[j];
      var id = c.id;
      if (id <= 0 || seen.contains(id)) id = j + 1;
      while (seen.contains(id)) {
        id++;
      }
      seen.add(id);
      if (c.id != id) c = c.copyWith(id: id);
      safe.add(c);
    }

    var i = _groups.indexWhere((g) => g.id == _activeId);
    if (i < 0) {
      // نسخهٔ خالی / گروه حذف‌شده: بی‌صدا دور نریز — یک گروه بساز.
      final g = await addGroup();
      i = _groups.indexWhere((g2) => g2.id == g.id);
      if (i < 0) return;
    }
    _groups[i] = _groups[i].copyWith(courses: safe);
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
  /// در نسخهٔ خالی هیچ گروهی برنمی‌گردد و لیست خالی قابل تغییر می‌ماند.
  Future<void> resetAllGroups() async {
    _groups = _defaultGroups();
    _activeId = _groups.isEmpty ? '' : _groups.first.id;
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
  /// روی همان مسیر واحد ایمپورت کار می‌کند تا رفتار تست و اپ یکی باشد.
  List<Course> parseCoursesOnly(String text) {
    // آرایهٔ خالی = برنامهٔ بدون درس (در ایمپورت رد می‌شود، در پارس مجاز است)
    final trimmed = text.trim();
    if (trimmed == '[]' || trimmed == '[ ]') return const [];
    return parseAnyToGroups(text).groups.first.courses;
  }

  /// یک نقطهٔ ورود برای همهٔ قالب‌های ممکن (کد CP2، فرمت خطی چت‌بات،
  /// پشتیبان کامل، تک‌گروه، آرایهٔ درس‌ها، آرایهٔ گروه‌ها) — خروجی: گروه‌ها.
  ///
  /// همهٔ ایمپورت‌ها از همین‌جا رد می‌شوند تا هیچ مسیری از اصلاحات جا نماند.
  ({List<CourseGroup> groups, String suggestedName, String? activeGroupId, bool isFullBackup})
      parseAnyToGroups(String rawText) {
    var text = rawText;

    // ۱) کد کوتاه پشتیبان
    final decoded = tryDecodeBackupCode(text);
    if (decoded != null) text = decoded;

    // ۲) فرمت خطی کوتاه چت‌بات
    if (isCompactPlanText(text)) {
      final p = parseCompactPlan(text);
      if (p.courses.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
      return (
        groups: [
          CourseGroup(id: 'g1', name: p.name.isEmpty ? kDefaultGroupName : p.name, courses: p.courses)
        ],
        suggestedName: p.name,
        activeGroupId: 'g1',
        isFullBackup: false,
      );
    }

    final data = _safeJson(text);
    if (data == null) {
      throw const FormatException(
          'فایل JSON سالم نیست (ساختار شکسته یا ناقصه) — دوباره از مبدأ کپی/دانلود کن');
    }

    final Map<String, dynamic>? map = data is Map
        ? <String, dynamic>{
            for (final e in data.entries) e.key.toString().toLowerCase(): e.value,
            for (final e in data.entries) e.key.toString(): e.value,
          }
        : null;

    // ۳) پشتیبان کاملِ همهٔ گروه‌ها
    final rawGroups = map?['groups'] ?? map?['گروه‌ها'];
    if (rawGroups is List) {
      final groups = [
        for (final g in rawGroups)
          if (g is Map) CourseGroup.fromJson(Map<String, dynamic>.from(g)),
      ];
      if (groups.isEmpty) throw const FormatException('فایل هیچ گروهی ندارد');
      final fixed = _normalizeGroupIds(groups);
      _validateGroups(fixed);
      return (
        groups: fixed,
        suggestedName: fixed.first.name,
        activeGroupId: (map?['activeGroupId'] ?? map?['فعال'])?.toString(),
        isFullBackup: true,
      );
    }

    // ۴) تک‌گروه زیر کلید group
    if (map != null && map['group'] is Map) {
      final g = CourseGroup.fromJson(Map<String, dynamic>.from(map['group'] as Map));
      _validateCourses(g.courses, g.name);
      return (groups: [g], suggestedName: g.name, activeGroupId: g.id, isFullBackup: false);
    }

    // ۵) آرایهٔ بدون پوشش: گروه‌ها یا درس‌ها؟
    if (data is List) {
      if (data.isEmpty) throw const FormatException('فایل هیچ درسی ندارد');
      final looksLikeGroups = data.every((e) =>
          e is Map && (_pickMapKey(e, ['courses', 'lessons', 'درس‌ها', 'جلسات']) is List));
      if (looksLikeGroups) {
        final groups = [
          for (final g in data)
            if (g is Map) CourseGroup.fromJson(Map<String, dynamic>.from(g)),
        ];
        final fixed = _normalizeGroupIds(groups);
        _validateGroups(fixed);
        return (
          groups: fixed,
          suggestedName: fixed.first.name,
          activeGroupId: fixed.first.id,
          isFullBackup: true,
        );
      }
    }

    // ۶) فهرست درس‌ها (با پوشش courses یا مستقیم)
    final courses = _decodeCourses(text);
    _validateCourses(courses, 'درس');
    var nm = '';
    if (map != null) {
      nm = (map['name'] ?? map['title'] ?? map['نام'] ?? '').toString().trim();
      // خروجی چت‌بات نام گروه را داخل {"plan":{"name":…}} می‌گذارد
      if (nm.isEmpty && map['plan'] is Map) {
        final p = map['plan'] as Map;
        nm = (p['name'] ?? p['نام'] ?? p['title'] ?? '').toString().trim();
      }
    }
    return (
      groups: [
        CourseGroup(id: 'g1', name: nm.isEmpty ? kDefaultGroupName : nm, courses: courses)
      ],
      suggestedName: nm,
      activeGroupId: 'g1',
      isFullBackup: false,
    );
  }

  /// شناسه‌های گروه را یکتا و غیرخالی می‌کند (فایل دست‌ساز اغلب تکراری دارد).
  List<CourseGroup> _normalizeGroupIds(List<CourseGroup> groups) {
    final used = <String>{};
    final out = <CourseGroup>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      var id = g.id.trim();
      if (id.isEmpty || used.contains(id)) id = 'g${i + 1}';
      while (used.contains(id)) {
        id = '${id}_';
      }
      used.add(id);
      out.add(g.id == id ? g : g.copyWith(id: id));
    }
    return out;
  }

  static dynamic _pickMapKey(dynamic m, List<String> keys) {
    if (m is! Map) return null;
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    final lower = {for (final e in m.entries) e.key.toString().toLowerCase(): e.value};
    for (final k in keys) {
      final v = lower[k.toLowerCase()];
      if (v != null) return v;
    }
    return null;
  }

  /// ارقام فارسی/عربی را فقط بیرون از رشته‌ها به لاتین تبدیل می‌کند
  /// (متن داخل «…» مثل نام درس و شمارهٔ کلاس دست‌نخورده می‌ماند).
  String _latinDigitsOutsideStrings(String s) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        out.write(ch);
        continue;
      }
      if (ch == '"') {
        inString = true;
        out.write(ch);
        continue;
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + (rune - 0x06F0));
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + (rune - 0x0660));
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  /// JSON را می‌خواند؛ اگر نشد null برمی‌گرداند (بدون پرتاب استثنای خام).
  dynamic _safeJson(String raw) {
    var s = extractJson(raw);
    try {
      return jsonDecode(s);
    } catch (_) {
      // تلاش دوم: ارقام فارسی بیرون رشته‌ها، حذف کامای اضافه، نقل‌قول فارسی
      s = _latinDigitsOutsideStrings(s)
          .replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!)
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
  /// همهٔ قالب‌ها از `parseAnyToGroups` می‌گذرند، پس هیچ فرمتی بدون اعتبارسنجی
  /// جایگزین نمی‌شود.
  Future<int> importJson(String text) async {
    final parsed = parseAnyToGroups(text);

    // پشتیبان کامل → همهٔ گروه‌ها جایگزین می‌شوند.
    // تک‌گروه / فهرست درس‌ها / فرمت خطی → فقط درس‌های گروه فعال.
    if (!parsed.isFullBackup) {
      final courses = parsed.groups.first.courses;
      if (courses.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
      await _setCourses(courses);
      return courses.length;
    }

    _groups = List<CourseGroup>.of(parsed.groups);
    final wanted = parsed.activeGroupId;
    _activeId = (wanted != null && _groups.any((g) => g.id == wanted))
        ? wanted
        : _groups.first.id;
    await _commit();
    return _groups.fold<int>(0, (s, g) => s + g.courses.length);
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
    final data = _safeJson(raw);
    if (data == null) {
      throw const FormatException('فایل JSON سالم نیست (ساختار شکسته یا ناقصه)');
    }
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
      final m = Map<String, dynamic>.from(item);
      // درسی که هیچ نامی ندارد، داده‌ی معتبر نیست — نباید جای درس‌های واقعی
      // را بگیرد («درس بدون نام» فقط برای رکوردهای ناقص داخل فایل خوب است).
      final hasName = ['name', 'title', 'نام', 'درس']
          .any((k) => m[k] != null && m[k].toString().trim().isNotEmpty);
      if (!hasName) continue;
      final c = Course.fromJson(m);
      out.add(c.id > 0 ? c : c.copyWith(id: i + 1));
    }
    if (out.isEmpty) throw const FormatException('هیچ درسی توی فایل پیدا نشد');
    return out;
  }

  List<CourseGroup> _decodeGroups(String raw) {
    final data = _safeJson(raw);
    if (data == null) throw const FormatException('فایل JSON سالم نیست (ساختار شکسته یا ناقصه)');
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
    final parsed = parseAnyToGroups(text);
    final courses = parsed.groups.first.courses;
    if (courses.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');

    final label = name.trim().isNotEmpty
        ? name.trim()
        : (parsed.suggestedName.trim().isNotEmpty ? parsed.suggestedName.trim() : '');
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
