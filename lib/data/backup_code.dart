import 'dart:convert';
import 'dart:io';

import '../jalali.dart';
import '../utils.dart';
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
//
// پارسر عمداً سخاوتمند است: ارقام فارسی/عربی، نام روز، ساعت «۰۸:۰۰»،
// بازهٔ «۸-۱۰» در یک ستون و ستون‌های کم‌شده را هم می‌پذیرد.

// \d در Dart فقط ارقام لاتین را می‌گیرد؛ چت‌بات اغلب «c۱|» می‌فرستد.
final _compactCourseRe = RegExp(r'^c[0-9۰-۹٠-٩]+\|');
final _compactHeadRe = RegExp(r'^PLAN\b');

// ── کمکی‌های تحمل‌پذیر ──

String _latin(String s) => s
    .replaceAllMapped(RegExp('[۰-۹]'), (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}')
    .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}')
    .replaceAll('٫', '.')
    .trim();

int? _asInt(String s) {
  final t = _latin(s);
  return int.tryParse(t) ?? double.tryParse(t)?.toInt();
}

/// «۸:۳۰» یا «8.5» یا «8» → ساعت اعشاری
double? _asHour(String s) {
  final t = _latin(s);
  if (t.isEmpty) return null;
  if (t.contains(':')) {
    final p = t.split(':');
    final h = int.tryParse(p[0].trim());
    if (h == null) return null;
    final m = p.length > 1 ? int.tryParse(p[1].trim()) : 0;
    return h + (m ?? 0) / 60.0;
  }
  return double.tryParse(t);
}

/// روز را از عدد (۰=شنبه) یا نام فارسی می‌خواند.
int? _asDay(String s) {
  final t = _latin(s).replaceAll('ي', 'ی').replaceAll('ك', 'ک');
  final i = kDayNames.indexOf(t);
  if (i >= 0) return i;
  final n = int.tryParse(t);
  if (n != null && n >= 0 && n <= 6) return n;
  return null;
}

/// «8-10» یا «۸ تا ۱۰» → (شروع، پایان)
(double, double)? _asRange(String s) {
  final t = _latin(s).replaceAll('تا', '-').replaceAll('_', '-');
  final m = RegExp(r'^([0-9:.]+)\s*-\s*([0-9:.]+)$').firstMatch(t);
  if (m == null) return null;
  final a = _asHour(m[1]!);
  final b = _asHour(m[2]!);
  if (a == null || b == null) return null;
  return b > a ? (a, b) : (a, a + (b - a).abs());
}

bool isCompactPlanText(String raw) {
  for (final line in raw.trim().split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('```')) continue; // بلوک کد چت‌بات‌ها
    if (_compactHeadRe.hasMatch(t) || _compactCourseRe.hasMatch(t)) return true;
    // حاشیهٔ چت‌بات («خب اینم برنامه:» و…) — تا چند خط اول دنبال سرنشین می‌گردیم
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
    final kind = parts[0].trim();

    if (_compactHeadRe.hasMatch(kind)) {
      for (final p in parts.skip(1)) {
        if (p.trim().startsWith('name=')) name = p.trim().substring(5).trim();
      }
      // «PLAN|ترم اول» بدون کلید name
      if (name.isEmpty && parts.length > 1) name = parts[1].trim();
      continue;
    }

    if (_compactCourseRe.hasMatch('$kind|')) {
      String field(int i) => i < parts.length ? parts[i].trim() : '';
      final id = _asInt(kind.substring(1));
      if (id == null) throw const FormatException('شناسهٔ درس نامعتبره');
      final courseName = field(1);
      if (courseName.isEmpty) throw const FormatException('خط درس بدون نام است (c…)');
      final units = _asInt(field(5)) ?? 2;
      if (units < 0 || units > 30) {
        throw FormatException('تعداد واحد درس «$courseName» نامعتبره');
      }
      var colorIdx = _asInt(field(6)) ?? 0;
      if (colorIdx < 0 || colorIdx >= kCoursePalette.length) colorIdx = 0;
      current = Course(
        id: id,
        name: courseName,
        short: field(2),
        prof: field(3),
        kind: field(4).isEmpty ? 'تخصصی' : field(4),
        units: units,
        colorValue: kCoursePalette[colorIdx],
        sessions: [],
      );
      courses.add(current);
      continue;
    }

    if (kind != 's' && kind != 'x') continue; // حاشیهٔ چت‌بات — خطوط ناشناخته نادیده

    if (current == null) {
      throw const FormatException('خط جلسه یا امتحان قبل از اولین درس اومده');
    }

    if (kind == 's') {
      String field(int i) => i < parts.length ? parts[i].trim() : '';
      final day = _asDay(field(1));
      var start = _asHour(field(2));
      var end = _asHour(field(3));
      final room = field(4);
      final type = field(5);
      if (start != null && end == null) {
        final r = _asRange(field(3).isEmpty ? field(2) : field(3));
        if (r != null) {
          start = r.$1;
          end = r.$2;
        }
      } else if (start == null) {
        final r = _asRange(field(2));
        if (r != null) {
          start = r.$1;
          end = r.$2;
        }
      }
      if (day == null || start == null || start < 0 || start > 24) {
        throw FormatException('جلسهٔ درس «${current.name}» نامعتبره (روز/ساعت)');
      }
      end ??= start + 2;
      if (end <= start || end > 24) end = start + 2;
      current = current.copyWith(
        sessions: [
          ...current.sessions,
          Session(
            day: day,
            start: start,
            end: end,
            room: room,
            type: type.isEmpty ? 'نظری' : type,
          ),
        ],
      );
      courses[courses.length - 1] = current;
      continue;
    }

    if (kind == 'x') {
      String field(int i) => i < parts.length ? parts[i].trim() : '';
      final jy = _asInt(field(1));
      final jm = _asInt(field(2));
      final jd = _asInt(field(3));
      final s = _asHour(field(4));
      final e = _asHour(field(5));
      if (jy == null ||
          jm == null ||
          jm < 1 ||
          jm > 12 ||
          jd == null ||
          jd < 1 ||
          jd > 31 ||
          s == null ||
          e == null) {
        throw FormatException('امتحان درس «${current.name}» نامعتبره (تاریخ/ساعت)');
      }
      current = current.copyWith(
        exam: Exam(
          date: JDate(jy, jm, jd),
          start: s,
          end: e > s ? e : s + 2,
          place: field(6),
        ),
      );
      courses[courses.length - 1] = current;
      continue;
    }

    // خطوط ناشناخته (مثل توضیحِ اضافهٔ چت‌بات) نادیده گرفته می‌شوند
    continue;
  }

  if (courses.isEmpty) throw const FormatException('هیچ درسی در متن پیدا نشد');
  // شناسه‌ها یکتا و مرتب
  for (var i = 0; i < courses.length; i++) {
    courses[i] = courses[i].copyWith(id: i + 1);
  }
  return (courses: courses, name: name.isEmpty ? '' : name.trim());
}
