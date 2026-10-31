#!/usr/bin/env python3
"""Faithful Python port of the Dart import pipeline (extractJson + _safeJson +
shape detection + tolerant fromJson). Used to verify import logic without a
Flutter toolchain. Keep in sync with lib/utils.dart and schedule_store.dart."""
import json
import re

DAY_NAMES = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه']
PALETTE0 = 0xFF2F6F8F


def extract_json(raw: str) -> str:
    s = raw.strip().lstrip('\ufeff')
    m = re.search(r'```[a-zA-Z]*\s*\n([\s\S]*?)```', s)
    if m:
        s = m.group(1).strip()
    o, a = s.find('{'), s.find('[')
    if a >= 0 and (o < 0 or a < o):
        start, end = a, s.rfind(']')
    else:
        start, end = o, s.rfind('}')
    if start < 0 or end <= start:
        return s
    return s[start:end + 1]


def latin_digits_outside_strings(s: str) -> str:
    out = []
    in_str = False
    esc = False
    for ch in s:
        if in_str:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                in_str = False
            out.append(ch)
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            continue
        cp = ord(ch)
        if 0x06F0 <= cp <= 0x06F9:
            out.append(chr(0x30 + cp - 0x06F0))
        elif 0x0660 <= cp <= 0x0669:
            out.append(chr(0x30 + cp - 0x0660))
        else:
            out.append(ch)
    return ''.join(out)


def safe_json(raw):
    s = extract_json(raw)
    try:
        return json.loads(s), None
    except Exception as e1:
        s2 = latin_digits_outside_strings(s)
        s2 = re.sub(r',(\s*[}\]])', r'\1', s2)
        s2 = s2.replace('“', '"').replace('”', '"')
        try:
            return json.loads(s2), None
        except Exception as e2:
            return None, str(e2)


def norm_digits(v: str) -> str:
    return (v.replace('۰', '0').replace('۱', '1').replace('۲', '2').replace('۳', '3')
            .replace('۴', '4').replace('۵', '5').replace('۶', '6').replace('۷', '7')
            .replace('۸', '8').replace('۹', '9')
            .replace('٠', '0').replace('١', '1').replace('٢', '2').replace('٣', '3')
            .replace('٤', '4').replace('٥', '5').replace('٦', '6').replace('٧', '7')
            .replace('٨', '8').replace('٩', '9')
            .replace('٫', '.').strip())


def pick(j, keys):
    if not isinstance(j, dict):
        return None
    for k in keys:
        if k in j and j[k] is not None:
            return j[k]
    lower = {str(k).lower(): v for k, v in j.items()}
    for k in keys:
        v = lower.get(k.lower())
        if v is not None:
            return v
    return None


def as_int(v, default):
    if v is None:
        return default
    if isinstance(v, (int, float)):
        return int(v)
    s = norm_digits(str(v))
    try:
        return int(s)
    except ValueError:
        try:
            return int(float(s))
        except ValueError:
            return default


def as_hour(v, default):
    if v is None:
        return default
    if isinstance(v, (int, float)):
        return float(v)
    s = norm_digits(str(v))
    if ':' in s:
        p = s.split(':')
        try:
            h = int(p[0].strip())
        except ValueError:
            return default
        m = 0
        if len(p) > 1:
            try:
                m = int(p[1].strip())
            except ValueError:
                m = 0
        return h + m / 60.0
    try:
        return float(s)
    except ValueError:
        return default


def as_day(v, default):
    if v is None:
        return default
    if isinstance(v, (int, float)):
        return int(v)
    s = norm_digits(str(v)).replace('ي', 'ی').replace('ك', 'ک')
    if s in DAY_NAMES:
        return DAY_NAMES.index(s)
    try:
        n = int(s)
        return n if 0 <= n <= 6 else default
    except ValueError:
        return default


PALETTE = [0xFF2F6F8F, 0xFFB8475A, 0xFF6B5AA6, 0xFFB8620E, 0xFFC2410C, 0xFF648C16,
           0xFFA3361F, 0xFF1F8A7A, 0xFF8A6D1A, 0xFF3B5BA9, 0xFF9C3D8F, 0xFF4A7C59]


def as_color(v):
    if v is None:
        return PALETTE0
    if isinstance(v, (int, float)):
        n = int(v)
        if 0 <= n < len(PALETTE):
            return PALETTE[n]
        if n <= 0xFFFFFF:
            return PALETTE0
        return n
    s = str(v).replace('#', '')
    if s.lower().startswith('0x'):
        s = s[2:]
    if len(s) == 6:
        s = 'FF' + s
    if len(s) == 8:
        try:
            return int(s, 16)
        except ValueError:
            return PALETTE0
    return PALETTE0


TRUE_WORDS = {'true', '1', 'yes', 'on', 'بله', 'آری', 'فعال', 'روشن'}
FALSE_WORDS = {'false', '0', 'no', 'off', 'خیر', 'نه', 'غیرفعال', 'خاموش'}


def as_bool(v, default=False):
    if v is None:
        return default
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return v != 0
    s = norm_digits(str(v)).lower().strip()
    if not s:
        return default
    if s in TRUE_WORDS:
        return True
    if s in FALSE_WORDS:
        return False
    return default


def session_from(j):
    day = as_day(pick(j, ['d', 'day', 'روز']) if pick(j, ['d', 'day', 'روز']) is not None else pick(j, ['weekday']), 0)
    if day < 0 or day > 6:
        day = 0
    start = as_hour(pick(j, ['s', 'start', 'شروع', 'from']), 8.0)
    end = as_hour(pick(j, ['e', 'end', 'پایان', 'to']), start + 2)
    if end <= start:
        end = start + 2
    return dict(day=day, start=min(max(start, 0), 24), end=min(max(end, 0), 24),
                room=str(pick(j, ['room', 'کلاس', 'place', 'location']) or '').strip(),
                type=(str(pick(j, ['t', 'type', 'نوع']) or '').strip() or 'نظری'),
                alarmOff=as_bool(pick(j, ['alarmOff', 'alarm_off', 'silent', 'بی‌صدا'])))


def exam_from(j):
    date = pick(j, ['date', 'تاریخ'])
    dm = date if isinstance(date, dict) else j
    jy = as_int(pick(dm, ['jy', 'y', 'year', 'سال']), 1405)
    jm = as_int(pick(dm, ['jm', 'm', 'month', 'ماه']), 1)
    jd = as_int(pick(dm, ['jd', 'd', 'day', 'روز']), 1)
    if not 1 <= jm <= 12:
        jm = 1
    if not 1 <= jd <= 31:
        jd = 1
    st = as_hour(pick(j, ['s', 'start', 'شروع']), 8.0)
    en = as_hour(pick(j, ['e', 'end', 'پایان']), st + 2)
    if en <= st:
        en = st + 2
    return dict(y=jy, m=jm, d=jd, start=st, end=en,
                place=str(pick(j, ['place', 'محل', 'room', 'location']) or '').strip())


def alarm_minutes_from(j):
    v = pick(j, ['alarmMinutes', 'alarm_minutes', 'alarm'])
    if v is None:
        return None
    n = as_int(v, -1)
    if n < 0:
        return None
    return min(n, 180)


def course_from(j, idx=0):
    name = str(pick(j, ['name', 'title', 'نام', 'درس']) or '').strip() or 'درس بدون نام'
    kind = str(pick(j, ['kind', 'نوع']) or '').strip() or 'تخصصی'
    sessions = pick(j, ['sessions', 'classes', 'جلسات', 'times'])
    if not isinstance(sessions, list):
        sessions = []
    return dict(
        id=as_int(pick(j, ['id', 'شناسه']), 0) or (idx + 1),
        name=name,
        prof=str(pick(j, ['prof', 'professor', 'teacher', 'استاد']) or '').strip(),
        units=as_int(pick(j, ['units', 'واحد', 'credits']), 2),
        color=as_color(pick(j, ['color', 'رنگ', 'colorValue'])),
        sessions=[session_from(s) for s in sessions if isinstance(s, dict)],
        exam=(exam_from(pick(j, ['exam', 'امتحان']))
              if isinstance(pick(j, ['exam', 'امتحان']), dict) else None),
        alarmMinutes=alarm_minutes_from(j),
    )


def decode_courses(text):
    data, err = safe_json(text)
    if data is None:
        raise ValueError('JSON نامعتبر: ' + str(err))
    lst = None
    if isinstance(data, list):
        lst = data
    elif isinstance(data, dict):
        lst = data.get('courses') or data.get('lessons') or data.get('درس‌ها')
        if lst is None and isinstance(data.get('group'), dict):
            g = data['group']
            lst = g.get('courses') or g.get('lessons') or g.get('درس‌ها')
        if lst is None:
            for v in data.values():
                if isinstance(v, list) and v and isinstance(v[0], dict) and (
                        'name' in v[0] or 'نام' in v[0]):
                    lst = v
                    break
    if not isinstance(lst, list):
        raise ValueError('فایل هیچ فهرست درسی نداره')
    out = []
    for i, c in enumerate(lst):
        if not isinstance(c, dict):
            continue
        has_name = any(c.get(k) is not None and str(c.get(k)).strip()
                       for k in ('name', 'title', 'نام', 'درس'))
        if not has_name:
            continue
        out.append(course_from(c, i))
    if not out:
        raise ValueError('هیچ درسی توی فایل پیدا نشد')
    return out


def detect_shape(text):
    """→ (kind, payload) like parseAnyToGroups."""
    data, err = safe_json(text)
    if data is None:
        raise ValueError('فایل JSON سالم نیست')
    mp = None
    if isinstance(data, dict):
        mp = {str(k).lower(): v for k, v in data.items()}
        for k, v in data.items():
            mp.setdefault(str(k), v)
    if mp is not None:
        raw_groups = mp.get('groups') or mp.get('گروه‌ها')
        if isinstance(raw_groups, list):
            groups = [g for g in raw_groups if isinstance(g, dict)]
            if not groups:
                raise ValueError('فایل هیچ گروهی ندارد')
            return 'full', [[course_from(c, i) for i, c in
                             enumerate(g.get('courses') or g.get('lessons') or g.get('درس‌ها') or [])
                             if isinstance(c, dict)] for g in groups]
        if isinstance(mp.get('group'), dict):
            g = mp['group']
            return 'single', [course_from(c, i) for i, c in
                              enumerate(g.get('courses') or g.get('lessons') or g.get('درس‌ها') or [])
                              if isinstance(c, dict)]
    if isinstance(data, list):
        if not data:
            raise ValueError('فایل هیچ درسی ندارد')
        looks_groups = all(isinstance(e, dict) and isinstance(
            pick(e, ['courses', 'lessons', 'درس‌ها', 'جلسات']), list) for e in data)
        if looks_groups:
            return 'full', [[course_from(c, i) for i, c in
                             enumerate(pick(g, ['courses', 'lessons', 'درس‌ها', 'جلسات']))
                             if isinstance(c, dict)] for g in data]
    return 'single', decode_courses(text)
