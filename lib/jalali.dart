/// تبدیل تاریخ شمسی ↔ میلادی (بدون پکیج اضافه)
class JDate {
  final int y, m, d;
  const JDate(this.y, this.m, this.d);

  factory JDate.fromDateTime(DateTime g) {
    final r = gregorianToJalali(g.year, g.month, g.day);
    return JDate(r[0], r[1], r[2]);
  }

  /// تاریخ میلادی (UTC، فقط روز)
  DateTime toDateTime() {
    final r = jalaliToGregorian(y, m, d);
    return DateTime.utc(r[0], r[1], r[2]);
  }

  int get weekdayIndex {
    // شنبه=۰ ... جمعه=۶
    final wd = toDateTime().weekday; // دوشنبه=۱ ... یکشنبه=۷
    return (wd + 1) % 7;
  }

  @override
  bool operator ==(Object other) => other is JDate && other.y == y && other.m == m && other.d == d;

  @override
  int get hashCode => Object.hash(y, m, d);
}

const List<String> kJalaliMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

List<int> gregorianToJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 + gd + gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm, jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + days % 31;
  } else {
    jm = 7 + (days - 186) ~/ 30;
    jd = 1 + (days - 186) % 30;
  }
  return [jy, jm, jd];
}

List<int> jalaliToGregorian(int jy, int jm, int jd) {
  jy += 1595;
  var days = -355668 + 365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4 + jd +
      (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days -= 1;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days += 1;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
  final sal = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var gm = 0;
  while (gm < 12 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm + 1, gd];
}

bool isJalaliLeap(int jy) {
  final g = jalaliToGregorian(jy, 12, 30);
  final back = gregorianToJalali(g[0], g[1], g[2]);
  return back[0] == jy && back[1] == 12 && back[2] == 30;
}

int jalaliMonthLength(int jy, int jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isJalaliLeap(jy) ? 30 : 29;
}
