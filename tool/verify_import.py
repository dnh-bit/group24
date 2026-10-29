#!/usr/bin/env python3
"""Runs the ported import pipeline against every fixture the app must accept."""
import json
import sys

sys.path.insert(0, '/home/ubuntu/workspace/group24/tool')
from import_logic import detect_shape, decode_courses, safe_json  # noqa: E402

CASES = []


def case(name, text, expect_kind=None, expect_first_course=None, expect_error=False):
    CASES.append((name, text, expect_kind, expect_first_course, expect_error))


case('همهٔ گروه‌ها (خروجی خود اپ)', '''
{"app":"course_plan","v":2,"activeGroupId":"g1","groups":[
 {"id":"g1","name":"گروه 24","courses":[
   {"id":1,"name":"ریاضی","units":3,"color":4284779542,
    "sessions":[{"d":0,"s":7.5,"e":9.5,"room":"204","t":"نظری"}]}]},
 {"id":"g2","name":"گروه 25","courses":[]}]}
''', 'full', 'ریاضی')

case('تک‌گروه زیر group', '{"group":{"name":"ترم اول","courses":[{"id":1,"name":"فلسفه","units":2}]}}',
     'single', 'فلسفه')

case('فهرست درس‌ها با کلید courses',
     '{"name":"ترم سوم","courses":[{"id":1,"name":"آمار","units":2}]}', 'single', 'آمار')

case('آرایهٔ بدون پوشش درس‌ها',
     '[{"id":1,"name":"الف","units":2},{"id":2,"name":"ب","units":3}]', 'single', 'الف')

case('آرایهٔ بدون پوشش گروه‌ها',
     '[{"id":"g1","name":"گ۱","courses":[{"id":1,"name":"الف","units":2}]}]', 'full', 'الف')

case('کلیدهای انگلیسی بلند + ساعت متنی + رنگ هگز', '''
{"lessons":[{"id":"x","title":"آموزش والدین","teacher":"دکتر","credits":"۲","color":"#648C16",
 "classes":[{"day":"یکشنبه","start":"08:00","end":"10:00","location":"۱۲","type":"عملی"}]}]}
''', 'single', 'آموزش والدین')

case('کلیدهای فارسی', '''
{"نام":"ترم اول","درس‌ها":[
 {"id":1,"نام":"فقه","استاد":"حجت","واحد":2,
  "جلسات":[{"روز":"شنبه","شروع":"۸:۰۰","پایان":"۱۰:۰۰","کلاس":"۱۰۱"}]}]}
''', 'single', 'فقه')

case('ارقام فارسی داخل ساختار', '{"courses":[{"id":۱,"name":"الف","units":۲}]}', 'single', 'الف')

case('کاماهای اضافه و نقل‌قول فارسی', '{“courses”:[{“id”:1,“name”:“الف”,“units”:2,},],}',
     'single', 'الف')

case('BOM ویندوزی', '\ufeff{"courses":[{"id":1,"name":"الف","units":2}]}', 'single', 'الف')

case('بلوک کد مارک‌داون', 'خب اینم:\n```json\n{"courses":[{"id":1,"name":"الف","units":2}]}\n```\nموفق باشی',
     'single', 'الف')

case('گروه بدون درس مجاز', '{"groups":[{"id":"g1","name":"خالی","courses":[]}]}', 'full', None)

# ── خطاها ──
for bad in ['سلام، این یک متن معمولی است', '{"courses": [ اینجا خراب است ]}', '{}', '[]',
            '{"foo": 1}', '{oops']:
    case(f'خطا باید بدهد: {bad[:24]}', bad, expect_error=True)


def main():
    ok = fail = 0
    for name, text, kind, first, expect_error in CASES:
        try:
            k, payload = detect_shape(text)
            if expect_error:
                print(f'❌ {name}: باید خطا می‌داد ولی {k} برگرداند')
                fail += 1
                continue
            courses = payload[0] if k == 'full' else payload
            got_first = courses[0]['name'] if courses else None
            if kind and k != kind:
                print(f'❌ {name}: نوع {k} != {kind}')
                fail += 1
                continue
            if first and got_first != first:
                print(f'❌ {name}: اولین درس «{got_first}» != «{first}»')
                fail += 1
                continue
            print(f'✅ {name} → {k}, {sum(len(c) for c in payload) if k=="full" else len(payload)} درس')
            ok += 1
        except Exception as e:
            if expect_error:
                print(f'✅ {name} → خطای درست: {e}')
                ok += 1
            else:
                print(f'❌ {name}: استثنا {e}')
                fail += 1

    # آزمون دقیق جزئیات
    print('\n=== جزئیات ===')
    cheks = []
    d = decode_courses('{"lessons":[{"id":"x","title":"آموزش","credits":"۲","color":"#648C16",'
                       '"classes":[{"day":"یکشنبه","start":"08:00","end":"10:00","type":"عملی"}]}]}')
    c = d[0]
    cheks.append(('title→name', c['name'] == 'آموزش'))
    cheks.append(('credits فارسی→۲', c['units'] == 2))
    cheks.append(('#648C16→int', c['color'] == 0xFF648C16))
    cheks.append(('day نام روز', c['sessions'][0]['day'] == 1))
    cheks.append(('"08:00"→8.0', c['sessions'][0]['start'] == 8.0))
    cheks.append(('type عملی', c['sessions'][0]['type'] == 'عملی'))

    d2 = decode_courses('{"courses":[{"id":1,"name":"x","units":2,"sessions":[{"d":0,"s":10,"e":10}]}]}')
    s = d2[0]['sessions'][0]
    cheks.append(('end<=start اصلاح می‌شود', s['end'] > s['start']))

    d3 = decode_courses('{"courses":[{"id":1,"name":"x","units":2,"color":"آبی","sessions":[]}]}')
    cheks.append(('رنگ نامعتبر→پالت', d3[0]['color'] == 0xFF2F6F8F))

    for label, res in cheks:
        print(('✅ ' if res else '❌ ') + label)
        ok += res
        fail += (not res)

    print(f'\nنتیجه: {ok} موفق، {fail} ناموفق')
    return 1 if fail else 0


if __name__ == '__main__':
    sys.exit(main())
