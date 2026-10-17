import 'package:flutter/material.dart';

import '../jalali.dart';
import '../utils.dart';

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
  bool overlaps(Session o) => o.day == day && start < o.end && o.start < end;

  Session copyWith({int? day, double? start, double? end, String? room, String? type}) => Session(
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
        room: room ?? this.room,
        type: type ?? this.type,
      );

  Map<String, dynamic> toJson() => {'d': day, 's': start, 'e': end, 'room': room, 't': type};

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        day: (j['d'] as num).toInt(),
        start: (j['s'] as num).toDouble(),
        end: (j['e'] as num).toDouble(),
        room: (j['room'] ?? '') as String,
        type: (j['t'] ?? 'نظری') as String,
      );
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

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        date: JDate((j['jy'] as num).toInt(), (j['jm'] as num).toInt(), (j['jd'] as num).toInt()),
        start: (j['s'] as num).toDouble(),
        end: (j['e'] as num).toDouble(),
        place: (j['place'] ?? '') as String,
      );
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

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        short: (j['short'] ?? '') as String,
        tiny: j['tiny'] as String?,
        prof: (j['prof'] ?? '') as String,
        kind: (j['kind'] ?? 'تخصصی') as String,
        units: ((j['units'] ?? 0) as num).toInt(),
        colorValue: ((j['color'] ?? 0xFF2F6F8F) as num).toInt(),
        exam: j['exam'] == null ? null : Exam.fromJson(Map<String, dynamic>.from(j['exam'] as Map)),
        sessions: [
          for (final s in (j['sessions'] as List? ?? const []))
            Session.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        note: (j['note'] ?? '') as String,
        muted: (j['muted'] ?? false) as bool,
      );
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

  factory CourseGroup.fromJson(Map<String, dynamic> j) => CourseGroup(
        id: (j['id'] ?? 'g1').toString(),
        name: (j['name'] ?? kDefaultGroupName).toString(),
        courses: [
          for (final c in (j['courses'] as List? ?? const []))
            Course.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
      );
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
