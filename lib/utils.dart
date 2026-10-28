import 'jalali.dart';

const _faDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Converts latin digits to Persian digits.
String fa(Object value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\d'), (m) => _faDigits[int.parse(m[0]!)]);

String pad2(int v) => v.toString().padLeft(2, '0');

/// 7.5 -> ۰۷:۳۰
String fmtTime(double hour) {
  final totalMin = (hour * 60).round();
  return fa('${pad2(totalMin ~/ 60)}:${pad2(totalMin % 60)}');
}

double hourFrom(int h, int m) => h + m / 60.0;

const List<String> kDayNames = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه'];

/// شنبه=۰ ... پنج‌شنبه=۵، جمعه=۶
int dayIndexOf(DateTime d) => (d.weekday + 1) % 7;

double hourOf(DateTime d) => d.hour + d.minute / 60.0;

/// «سه‌شنبه ۲۱ مهر ۱۴۰۵»
String jalaliLong(DateTime now) {
  final j = JDate.fromDateTime(now);
  return '${kDayNames[dayIndexOf(now)]} ${fa(j.d)} ${kJalaliMonths[j.m - 1]} ${fa(j.y)}';
}

/// متن خام (مثلاً خروجی چت‌بات) را به یک متن JSON تمیز تبدیل می‌کند.
///
/// چت‌بات‌ها معمولاً خروجی را داخل بلوک کد ```json ... ``` می‌گذارند یا
/// توضیح قبل و بعد از JSON می‌نویسند؛ این تابع اولین شیء {...} را برمی‌دارد.
String extractJson(String raw) {
  var s = raw.trim().replaceFirst('\uFEFF', '');
  // بلوک‌های کد مارک‌داون را می‌شکنیم
  final fence = RegExp(r'```[a-zA-Z]*\s*\n([\s\S]*?)```').firstMatch(s);
  if (fence != null) s = fence.group(1)!.trim();
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) return s;
  return s.substring(start, end + 1);
}
