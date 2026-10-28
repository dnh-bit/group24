import 'dart:convert';
import 'dart:io';

import '../jalali.dart';
import 'models.dart';

/// «کد کوتاه پشتیبان» — همان JSON خود برنامه، فشرده با gzip و کدگذاری base64.
///
/// پیشوند CP2: دارد؛ خطوط شکسته یا فاصله‌دار (مثل وقتی از چت کپی می‌شود)
/// پاک می‌شوند. حجم را نسبت به JSON مرتب‌شده حدوداً ۷۰٪ کم می‌کند.
const String kBackupCodePrefix = 'CP2:';

String encodeBackupCode(String json) {
  final gz = gzip.encode(utf8.encode(json));
  return kBackupCodePrefix + base64Url.encode(gz);
}

/// اگر متن یک کد پشتیبان باشد JSON اصلی را برمی‌گرداند، وگرنه null.
String? tryDecodeBackupCode(String raw) {
  var s = raw.trim().replaceFirst('\uFEFF', '');
  if (!s.startsWith(kBackupCodePrefix)) return null;
  // فاصله و خط جدید (کپی از چت) بی‌اثر می‌شوند
  s = s.replaceAll(RegExp(r'\s'), '');
  try {
    final gz = base64Url.decode(s.substring(kBackupCodePrefix.length));
    return utf8.decode(gzip.decode(gz));
  } catch (_) {
    return null;
  }
}

// ───────────── فرمت خطی کوتاه (خروجی چت‌بات) ─────────────
//
// PLAN|name=ترم اول ۱۴۰۵
// c1|نام درس|نام کوتاه|استاد|نوع|واحد|رنگ
// s|روز|شروع|پایان|کلاس|نظری/عملی
// x|سال|ماه|روز|شروع|پایان|محل امتحان
//
// خط s و x مالِ آخرین درس c هستند. جداکننده | و داخل فیلدها ممنوع.

final _compactCourseRe = RegExp(r'^c(\d+)\|');
final _compactHeadRe = RegExp(r'^PLAN\b');

bool isCompactPlanText(String raw) {
  for (final line in raw.trim().split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('```')) continue; // بلوک کد چت‌بات‌ها
    return _compactHeadRe.hasMatch(t) || _compactCourseRe.hasMatch(t);
  }
  return false;
}

/// متن خطی کوتاه را به درس‌ها تبدیل می‌کند. نام گروه را هم اگر بود برمی‌گرداند.
/// خطای قالب → FormatException با پیام فارسی.
({List<Course> courses, String name}) parseCompactPlan(String raw) {
  final courses = <Course>[];
  var name = '';
  Course? current;

  for (final line0 in raw.trim().split('\n')) {
    final line = line0.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('```')) continue;
    final parts = line.split('|');

    if (_compactHeadRe.hasMatch(parts[0])) {
      for (final p in parts.skip(1)) {
        if (p.startsWith('name=')) name = p.substring(5).trim();
      }
      continue;
    }

    final kind = parts[0];
    if (kind.startsWith('c')) {
      if (parts.length < 7) {
        throw const FormatException('خط درس ناقصه (c…)');
      }
      final id = int.tryParse(kind.substring(1));
      if (id == null) throw const FormatException('شناسهٔ درس نامعتبره');
      final units = int.tryParse(parts[5].trim());
      if (units == null || units < 0 || units > 30) {
        throw FormatException('تعداد واحد درس «${parts[1]}» نامعتبره');
      }
      var colorIdx = int.tryParse(parts[6].trim()) ?? 0;
      if (colorIdx < 0 || colorIdx >= kCoursePalette.length) colorIdx = 0;
      current = Course(
        id: id,
        name: parts[1].trim(),
        short: parts[2].trim(),
        prof: parts[3].trim(),
        kind: parts[4].trim().isEmpty ? 'تخصصی' : parts[4].trim(),
        units: units,
        colorValue: kCoursePalette[colorIdx],
        sessions: [],
      );
      courses.add(current);
      continue;
    }

    if (current == null) {
      throw const FormatException('خط جلسه یا امتحان قبل از اولین درس اومده');
    }

    if (kind == 's') {
      if (parts.length < 6) throw const FormatException('خط جلسه ناقصه (s…)');
      final day = int.tryParse(parts[1].trim());
      final start = double.tryParse(parts[2].trim());
      final end = double.tryParse(parts[3].trim());
      if (day == null || day < 0 || day > 6 || start == null || end == null || end <= start) {
        throw FormatException('جلسهٔ درس «${current.name}» نامعتبره');
      }
      current = current.copyWith(
        sessions: [...current.sessions, Session(day: day, start: start, end: end,
            room: parts[4].trim(), type: parts[5].trim().isEmpty ? 'نظری' : parts[5].trim())],
      );
      courses[courses.length - 1] = current;
      continue;
    }

    if (kind == 'x') {
      if (parts.length < 6) throw const FormatException('خط امتحان ناقصه (x…)');
      final jy = int.tryParse(parts[1].trim());
      final jm = int.tryParse(parts[2].trim());
      final jd = int.tryParse(parts[3].trim());
      final s = double.tryParse(parts[4].trim());
      final e = double.tryParse(parts[5].trim());
      if (jy == null || jm == null || jm < 1 || jm > 12 || jd == null || jd < 1 ||
          s == null || e == null || e <= s) {
        throw FormatException('امتحان درس «${current.name}» نامعتبره');
      }
      current = current.copyWith(
        exam: Exam(date: JDate(jy, jm, jd), start: s, end: e, place: parts.length > 6 ? parts[6].trim() : ''),
      );
      courses[courses.length - 1] = current;
      continue;
    }

    // خطوط ناشناخته (مثل توضیحِ اضافهٔ چت‌بات) نادیده گرفته می‌شوند
    continue;
  }

  if (courses.isEmpty) throw const FormatException('هیچ درسی پیدا نشد');
  // اگر شناسه‌ها پراکنده بودند، مرتب و یکتا می‌کنیم
  for (var i = 0; i < courses.length; i++) {
    courses[i] = courses[i].copyWith(id: i + 1);
  }
  return (courses: courses, name: name.isEmpty ? '' : name.trim());
}
