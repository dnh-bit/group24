import 'package:flutter/material.dart';

import '../jalali.dart';
import '../utils.dart';

// ───────────── خواندن تحمل‌پذیر JSON ─────────────
// خروجی چت‌بات‌ها و فایل‌های دست‌ساز، کلیدها و نوع‌های متفاوتی دارند
// (day/روز، start/"08:00"، color:"#2F6F8F"، id به‌صورت متن، ارقام فارسی).
// این توابع همه را به یک مقدار سالم تبدیل می‌کنند تا ایمپورت بی‌دلیل رد نشود.

String _normDigits(String s) => s
    .replaceAllMapped(RegExp('[۰-۹]'), (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}')
    .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}')
    .replaceAll('\u066B', '.')
    .trim();

dynamic _pick(Map j, List<String> keys) {
  for (final k in keys) {
    if (j.containsKey(k) && j[k] != null) return j[k];
  }
  // کلیدهای با حروف بزرگ/کوچک متفاوت
  final lower = {for (final e in j.entries) e.key.toString().toLowerCase(): e.value};
  for (final k in keys) {
    final v = lower[k.toLowerCase()];
    if (v != null) return v;
  }
  return null;
}

String _str(dynamic v, [String def = '']) {
  if (v == null) return def;
  if (v is String) return v.trim();
  return v.toString().trim();
}

int _int(dynamic v, int def) {
  if (v == null) return def;
  if (v is num) return v.toInt();
  final s = _normDigits(v.toString());
  return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? def;
}

double _dbl(dynamic v, double def) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  final s = _normDigits(v.toString());
  if (s.contains(':')) {
    final p = s.split(':');
    final h = int.tryParse(p[0].trim());
    final m = int.tryParse(p.length > 1 ? p[1].trim() : '0');
    if (h != null) return h + (m ?? 0) / 60.0;
  }
  return double.tryParse(s) ?? def;
}

int _dayOf(dynamic v, int def) {
  if (v == null) return def;
  if (v is num) return v.toInt();
  final s = _normDigits(v.toString()).replaceAll('ي', 'ی').replaceAll('ك', 'ک');
  final i = kDayNames.indexOf(s);
  if (i >= 0) return i;
  return int.tryParse(s) ?? def;
}

int _colorOf(dynamic v) {
  if (v == null) return kCoursePalette[0];
  if (v is num) return v.toInt();
  var s = _str(v).replaceFirst('#', '');
  if (s.toLowerCase().startsWith('0x')) s = s.substring(2);
  if (s.length == 6) s = 'FF$s';
  if (s.length == 8) {
    final parsed = int.tryParse(s, radix: 16);
    if (parsed != null) return parsed;
  }
  return kCoursePalette[0];
}

class Session {
  final int day; // ۰=شنبه ... ۶=جمعه
  final double start; // ساعت اعشاری: 7.5 یعنی ۷:۳۰
  final double end;
  final String room;
  final String type; // نظری / عملی

  const Session({
    required this.day,
    required this.start,
    required this.end,
    this.room = '',
    this.type = 'نظری',
  });

  double get length => end - start;

  /// جلسات یک‌ساعته در این برنامه برگزار نمی‌شن (قاعدهٔ کتبی کاربر)؛
  /// خاکستری می‌شن، اعلان ندارن و در «کلاس بعدی» هم ظاهر نمی‌شن.
  bool get isOneHour => (length - 1.0).abs() < 0.001;

  bool overlaps(Session o) => o.day == day && start < o.end && o.start < end;

  Session copyWith({int? day, double? start, double? end, String? room, String? type}) => Session(
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
        room: room ?? this.room,
        type: type ?? this.type,
      );

  Map<String, dynamic> toJson() => {'d': day, 's': start, 'e': end, 'room': room, 't': type};

  factory Session.fromJson(Map<String, dynamic> j) {
    var day = _dayOf(_pick(j, ['d', 'day', 'روز']) ?? _pick(j, ['weekday']), 0);
    if (day < 0 || day > 6) day = 0;
    final start = _dbl(_pick(j, ['s', 'start', 'شروع', 'from']), 8);
    var end = _dbl(_pick(j, ['e', 'end', 'پایان', 'to']), start + 2);
    if (end <= start) end = start + 2;
    return Session(
      day: day,
      start: start.clamp(0.0, 24.0),
      end: end.clamp(0.0, 24.0),
      room: _str(_pick(j, ['room', 'کلاس', 'place', 'location'])),
      type: _str(_pick(j, ['t', 'type', 'نوع']), 'نظری').isEmpty
          ? 'نظری'
          : _str(_pick(j, ['t', 'type', 'نوع']), 'نظری'),
    );
  }
}

class Exam {
  final JDate date;
  final double start;
  final double end;
  final String place;

  const Exam({required this.date, required this.start, required this.end, this.place = ''});

  DateTime get gregorian => date.toDateTime();
  String get jalaliText => fa('${date.y}/${pad2(date.m)}/${pad2(date.d)}');
  String get dayText => fa(pad2(date.d));
  String get monthName => kJalaliMonths[date.m - 1];
  String get timeText => '${fmtTime(start)} تا ${fmtTime(end)}';
  String get weekdayName => kDayNames[date.weekdayIndex];

  /// چند روز مانده (بر اساس روز تقویمی)
  int daysLeft(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    return gregorian.difference(today).inDays;
  }

  Exam copyWith({JDate? date, double? start, double? end, String? place}) => Exam(
        date: date ?? this.date,
        start: start ?? this.start,
        end: end ?? this.end,
        place: place ?? this.place,
      );

  Map<String, dynamic> toJson() =>
      {'jy': date.y, 'jm': date.m, 'jd': date.d, 's': start, 'e': end, 'place': place};

  factory Exam.fromJson(Map<String, dynamic> j) {
    final date = _pick(j, ['date', 'تاریخ']);
    final dateMap = date is Map ? Map<String, dynamic>.from(date) : j;
    final jy = _int(_pick(dateMap, ['jy', 'y', 'year', 'سال']), 1405);
    var jm = _int(_pick(dateMap, ['jm', 'm', 'month', 'ماه']), 1);
    var jd = _int(_pick(dateMap, ['jd', 'd', 'day', 'روز']), 1);
    if (jm < 1 || jm > 12) jm = 1;
    if (jd < 1 || jd > 31) jd = 1;
    final start = _dbl(_pick(j, ['s', 'start', 'شروع']), 8);
    var end = _dbl(_pick(j, ['e', 'end', 'پایان']), start + 2);
    if (end <= start) end = start + 2;
    return Exam(
      date: JDate(jy, jm, jd),
      start: start.clamp(0.0, 24.0),
      end: end.clamp(0.0, 24.0),
      place: _str(_pick(j, ['place', 'محل', 'room', 'location'])),
    );
  }
}

class Course {
  final int id;
  final String name;
  final String short;
  final String? tiny;
  final String prof;
  final String kind;
  final int units;
  final int colorValue;
  final Exam? exam;
  final List<Session> sessions;
  final String note;
  final bool muted; // یادآوری‌های این درس خاموش

  const Course({
    required this.id,
    required this.name,
    this.short = '',
    this.tiny,
    this.prof = '',
    this.kind = 'تخصصی',
    this.units = 2,
    required this.colorValue,
    this.exam,
    this.sessions = const [],
    this.note = '',
    this.muted = false,
  });

  Color get color => Color(colorValue);
  String get shortName => short.trim().isEmpty ? name : short;
  String get tinyName => (tiny == null || tiny!.trim().isEmpty) ? shortName : tiny!;

  Course copyWith({
    int? id,
    String? name,
    String? short,
    String? tiny,
    String? prof,
    String? kind,
    int? units,
    int? colorValue,
    Exam? exam,
    bool clearExam = false,
    List<Session>? sessions,
    String? note,
    bool? muted,
  }) =>
      Course(
        id: id ?? this.id,
        name: name ?? this.name,
        short: short ?? this.short,
        tiny: tiny ?? this.tiny,
        prof: prof ?? this.prof,
        kind: kind ?? this.kind,
        units: units ?? this.units,
        colorValue: colorValue ?? this.colorValue,
        exam: clearExam ? null : (exam ?? this.exam),
        sessions: sessions ?? this.sessions,
        note: note ?? this.note,
        muted: muted ?? this.muted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'short': short,
        if (tiny != null) 'tiny': tiny,
        'prof': prof,
        'kind': kind,
        'units': units,
        'color': colorValue,
        if (exam != null) 'exam': exam!.toJson(),
        'sessions': [for (final s in sessions) s.toJson()],
        'note': note,
        'muted': muted,
      };

  factory Course.fromJson(Map<String, dynamic> j) {
    final exam = _pick(j, ['exam', 'امتحان']);
    final sessions = _pick(j, ['sessions', 'classes', 'جلسات', 'times']);
    final name = _str(_pick(j, ['name', 'title', 'نام', 'درس']), 'درس بدون نام');
    return Course(
      id: _int(_pick(j, ['id', 'شناسه']), 0),
      name: name.isEmpty ? 'درس بدون نام' : name,
      short: _str(_pick(j, ['short', 'کوتاه', 'shortName'])),
      tiny: _pick(j, ['tiny']) == null ? null : _str(_pick(j, ['tiny'])),
      prof: _str(_pick(j, ['prof', 'professor', 'teacher', 'استاد'])),
      kind: _str(_pick(j, ['kind', 'نوع'], 'تخصصی'), 'تخصصی').isEmpty
          ? 'تخصصی'
          : _str(_pick(j, ['kind', 'نوع'], 'تخصصی'), 'تخصصی'),
      units: _int(_pick(j, ['units', 'واحد', 'credits']), 2),
      colorValue: _colorOf(_pick(j, ['color', 'رنگ', 'colorValue'])),
      exam: exam is Map ? Exam.fromJson(Map<String, dynamic>.from(exam)) : null,
      sessions: [
        for (final s in (sessions is List ? sessions : const []))
          if (s is Map) Session.fromJson(Map<String, dynamic>.from(s)),
      ],
      note: _str(_pick(j, ['note', 'یادداشت'])),
      muted: _pick(j, ['muted']) == true,
    );
  }
}

class SessionRef {
  final Course course;
  final Session session;
  final int index;
  const SessionRef(this.course, this.session, this.index);
}

class NextClass {
  final SessionRef ref;
  final int daysAhead;
  final bool ongoing;
  const NextClass(this.ref, this.daysAhead, this.ongoing);

  String get whenLabel {
    if (daysAhead == 0) return 'امروز';
    if (daysAhead == 1) return 'فردا';
    return kDayNames[ref.session.day];
  }
}

class Conflict {
  final SessionRef a;
  final SessionRef b;
  const Conflict(this.a, this.b);
}

/// یک «گروه درسی» با برنامهٔ خودش.
///
/// هر گروه مجموعهٔ مستقل خودش از درس‌ها و جلسه‌ها را دارد؛ کاربر می‌تواند
/// چند گروه بسازد و بین‌شان جابه‌جا شود. فقط گروه فعال روی صفحهٔ اصلی، جدول
/// هفتگی، فصل امتحان‌ها و اعلان‌ها اثر می‌گذارد.
class CourseGroup {
  final String id;
  final String name;
  final List<Course> courses;

  const CourseGroup({
    required this.id,
    required this.name,
    this.courses = const [],
  });

  CourseGroup copyWith({String? id, String? name, List<Course>? courses}) => CourseGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        courses: courses ?? this.courses,
      );

  int get totalUnits => courses.fold(0, (s, c) => s + c.units);

  int get sessionCount => courses.fold(0, (s, c) => s + c.sessions.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'courses': [for (final c in courses) c.toJson()],
      };

  factory CourseGroup.fromJson(Map<String, dynamic> j) {
    final courses = _pick(j, ['courses', 'lessons', 'در', 'درس‌ها']);
    return CourseGroup(
      id: _str(_pick(j, ['id']), 'g1'),
      name: _str(_pick(j, ['name', 'title', 'نام']), kDefaultGroupName),
      courses: [
        for (final c in (courses is List ? courses : const []))
          if (c is Map) Course.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }
}

/// پالت رنگ‌های درس‌ها (همون رنگ‌های نسخهٔ وب + چند تا اضافه)
const List<int> kCoursePalette = [
  0xFF2F6F8F, 0xFFB8475A, 0xFF6B5AA6, 0xFFB8620E, 0xFFC2410C, 0xFF648C16,
  0xFFA3361F, 0xFF1F8A7A, 0xFF8A6D1A, 0xFF3B5BA9, 0xFF9C3D8F, 0xFF4A7C59,
];

const List<String> kCourseKinds = ['تخصصی', 'عمومی', 'معارف', 'پایه', 'کارورزی', 'اختیاری'];
const List<String> kSessionTypes = ['نظری', 'عملی'];

/// نام پیش‌فرض گروه اول (برنامهٔ گروه ۲۴).
const String kDefaultGroupName = 'برنامه درسی گروه ۲۴';

/// نام پیش‌فرض گروه دوم (برنامهٔ گروه ۲۵).
const String kG25GroupName = 'برنامه درسی گروه ۲۵';
