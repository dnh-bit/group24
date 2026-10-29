#!/usr/bin/env python3
"""Faithful port of lib/data/backup_code.dart compact-line parser + fixtures."""
import re
import sys

DAY_NAMES = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه']
PALETTE_LEN = 12
COURSE_RE = re.compile(r'^c(\d+)\|')
HEAD_RE = re.compile(r'^PLAN\b')


def latin(s):
    out = []
    for ch in s:
        cp = ord(ch)
        if 0x06F0 <= cp <= 0x06F9:
            out.append(chr(0x30 + cp - 0x06F0))
        elif 0x0660 <= cp <= 0x0669:
            out.append(chr(0x30 + cp - 0x0660))
        elif ch == '٫':
            out.append('.')
        else:
            out.append(ch)
    return ''.join(out).strip()


def as_int(s):
    t = latin(s)
    try:
        return int(t)
    except ValueError:
        try:
            return int(float(t))
        except ValueError:
            return None


def as_hour(s):
    t = latin(s)
    if not t:
        return None
    if ':' in t:
        p = t.split(':')
        try:
            h = int(p[0].strip())
        except ValueError:
            return None
        m = 0
        if len(p) > 1:
            try:
                m = int(p[1].strip())
            except ValueError:
                m = 0
        return h + m / 60.0
    try:
        return float(t)
    except ValueError:
        return None


def as_day(s):
    t = latin(s).replace('ي', 'ی').replace('ك', 'ک')
    if t in DAY_NAMES:
        return DAY_NAMES.index(t)
    n = as_int(t)
    if n is not None and 0 <= n <= 6:
        return n
    return None


def as_range(s):
    t = latin(s).replace('تا', '-').replace('_', '-')
    m = re.match(r'^([0-9:.]+)\s*-\s*([0-9:.]+)$', t)
    if not m:
        return None
    a, b = as_hour(m.group(1)), as_hour(m.group(2))
    if a is None or b is None:
        return None
    return (a, b) if b > a else (a, a + abs(b - a))


def is_compact(raw):
    for line in raw.strip().split('\n'):
        t = line.strip()
        if not t or t.startswith('```'):
            continue
        if HEAD_RE.match(t) or COURSE_RE.match(t):
            return True
    return False


def parse(raw):
    courses = []
    name = ''
    cur = None
    for line0 in raw.strip().split('\n'):
        line = line0.strip()
        if not line or line.startswith('#') or line.startswith('```'):
            continue
        parts = line.split('|')
        kind = parts[0].strip()

        if HEAD_RE.match(kind):
            for p in parts[1:]:
                if p.strip().startswith('name='):
                    name = p.strip()[5:].strip()
            if not name and len(parts) > 1:
                name = parts[1].strip()
            continue

        if COURSE_RE.match(kind + '|'):
            f = lambda i: parts[i].strip() if i < len(parts) else ''
            cid = as_int(kind[1:])
            if cid is None:
                raise ValueError('شناسهٔ درس نامعتبره')
            cname = f(1)
            if not cname:
                raise ValueError('خط درس بدون نام است')
            units = as_int(f(5))
            units = 2 if units is None else units
            if units < 0 or units > 30:
                raise ValueError(f'تعداد واحد «{cname}» نامعتبره')
            color = as_int(f(6)) or 0
            if color < 0 or color >= PALETTE_LEN:
                color = 0
            cur = dict(id=cid, name=cname, short=f(2), prof=f(3),
                       kind=f(4) or 'تخصصی', units=units, color=color, sessions=[],
                       exam=None)
            courses.append(cur)
            continue

        if kind not in ('s', 'x'):
            continue
        if cur is None:
            raise ValueError('خط جلسه قبل از اولین درس')
        f = lambda i: parts[i].strip() if i < len(parts) else ''

        if kind == 's':
            day = as_day(f(1))
            start = as_hour(f(2))
            end = as_hour(f(3))
            room, typ = f(4), f(5)
            if start is not None and end is None:
                r = as_range(f(3) if f(3) else f(2))
                if r:
                    start, end = r
            elif start is None:
                r = as_range(f(2))
                if r:
                    start, end = r
            if day is None or start is None or start < 0 or start > 24:
                raise ValueError(f'جلسهٔ «{cur["name"]}» نامعتبره')
            if end is None:
                end = start + 2
            if end <= start or end > 24:
                end = start + 2
            cur['sessions'].append(dict(day=day, start=start, end=end,
                                        room=room, type=typ or 'نظری'))
            continue

        if kind == 'x':
            jy, jm, jd = as_int(f(1)), as_int(f(2)), as_int(f(3))
            s, e = as_hour(f(4)), as_hour(f(5))
            if (jy is None or jm is None or not 1 <= jm <= 12 or jd is None
                    or not 1 <= jd <= 31 or s is None or e is None):
                raise ValueError(f'امتحان «{cur["name"]}» نامعتبره')
            cur['exam'] = dict(jy=jy, jm=jm, jd=jd, start=s, end=e if e > s else s + 2, place=f(6))
            continue

    if not courses:
        raise ValueError('هیچ درسی در متن پیدا نشد')
    for i, c in enumerate(courses):
        c['id'] = i + 1
    return dict(name=name.strip(), courses=courses)


CASES = []


def case(label, text, check, expect_error=False):
    CASES.append((label, text, check, expect_error))


case('شکل استاندارد', '''
PLAN|name=ترم اول ۱۴۰۵
c1|آموزش والدین|والدین|دکتر احمدی|تخصصی|2|3
s|1|7.5|9.5|204|نظری
c2|کارگاه نمایشنامه|نمایشنامه|استاد رضایی|عمومی|2|5
s|6|7.5|9.5|LMS|عملی
x|1405|10|29|8|10|سالن
''', lambda r: (r['name'] == 'ترم اول ۱۴۰۵' and len(r['courses']) == 2
                and r['courses'][0]['sessions'][0]['day'] == 1
                and r['courses'][1]['exam']['jd'] == 29))

case('ارقام فارسی + نام روز + ساعت متنی', '''
PLAN|name=ترم دوم
c۱|ریاضی|ریاضی|استاد|تخصصی|۳|۰
s|یکشنبه|۰۸:۰۰|۱۰:۰۰|کلاس ۱۲|نظری
''', lambda r: (r['courses'][0]['units'] == 3
                and r['courses'][0]['sessions'][0]['day'] == 1
                and r['courses'][0]['sessions'][0]['start'] == 8.0
                and r['courses'][0]['sessions'][0]['end'] == 10.0))

case('بازهٔ «۸-۱۰» در یک ستون', '''
c1|فارسی|فارسی||عمومی|2|1
s|0|۸-۱۰|کلاس|نظری
''', lambda r: (r['courses'][0]['sessions'][0]['start'] == 8.0
                and r['courses'][0]['sessions'][0]['end'] == 10.0))

case('ستون‌های کم + توضیح اضافهٔ چت‌بات', '''
سلام! این هم برنامه‌ت:

```
PLAN|نام=ترم اول
c1|علوم|علوم|استاد|پایه|2
s|2|10|12
```

امیدوارم مفید باشه.
''', lambda r: len(r['courses']) == 1 and r['courses'][0]['sessions'][0]['start'] == 10.0)

case('ساعت معکوس اصلاح می‌شود نه رد', '''
PLAN|name=x
c1|درس|درس|استاد|تخصصی|2|0
s|0|10|9|کلاس|نظری
''', lambda r: (r['courses'][0]['sessions'][0]['start'] == 10.0
                and r['courses'][0]['sessions'][0]['end'] > 10.0))

case('روز/ساعت نامفهوم باید خطا بدهد', '''
PLAN|name=x
c1|درس|درس|استاد|تخصصی|2|0
s|هیچ‌روز|نامعلوم|کلاس|نظری
''', lambda r: False, expect_error=True)

case('PLAN| نام بدون کلید name', '''
PLAN|ترم چهارم
c1|درس|درس|استاد|تخصصی|2|0
s|0|8|10|کلاس|نظری
''', lambda r: r['name'] == 'ترم چهارم')


def main():
    ok = fail = 0
    for label, text, check, expect_error in CASES:
        try:
            r = parse(text)
            if expect_error:
                print(f'❌ {label}: باید خطا می‌داد')
                fail += 1
                continue
            res = check(r)
            print(('✅ ' if res else '❌ ') + label)
            ok += res
            fail += (not res)
        except ValueError as e:
            if expect_error:
                print(f'✅ {label} → خطای درست: {e}')
                ok += 1
            else:
                print(f'❌ {label}: {e}')
                fail += 1
    print(f'\nنتیجه: {ok} موفق، {fail} ناموفق')
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())
