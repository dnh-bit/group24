import sys
# بررسی زمان‌بندی آلارم بدون نیاز به Flutter (پورت منطق _nextWeekly و آلارم امتحان)
sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__))))

def next_weekly(now_min_of_week, day, start_hour, minutes_before):
    """معادل _nextWeekly در Dart: نزدیک‌ترین زمان آینده (دقیقه از ابتدای هفته)."""
    target = (day * 24 * 60) + round(start_hour*60) - minutes_before
    # نرمال‌سازی: ممکن است منفی شود (آلارم ۳۰ دقیقه قبل برای کلاس ۰۰:۱۰)
    weeks = 7*24*60
    t = target % weeks
    # نزدیک‌ترین آینده
    delta = (t - now_min_of_week) % weeks
    if delta == 0: delta = weeks
    return now_min_of_week + delta

def hm(min_of_week):
    d = (min_of_week // 1440) % 7
    m = min_of_week % 1440
    return f'{"ش ی د س چ پ ج"[0] if False else ""}{d}روز {m//60:02d}:{m%60:02d}'

fail=0
def check(name, got, want):
    global fail
    ok = got==want
    if not ok: fail+=1
    print(('OK ' if ok else 'FAIL ')+name, '' if ok else f'got={got} want={want}')

# شنبه = 0. «الان» = شنبه ساعت ۱۰:۰۰ = 600 دقیقه
now = 600
# کلاس شنبه ۱۰:۳۰، آلارم ۱۵ دقیقه قبل → ۱۰:۱۵ = 615
check('کلاس شنبه ۱۰:۳۰ منهای ۱۵ دقیقه', next_weekly(now,0,10.5,15), 615)
# کلاس شنبه ۸:۰۰، آلارم ۱۵ قبل → گذشته (۷:۴۵ < ۱۰:۰۰) → هفتهٔ بعد
check('کلاس گذشته → هفتهٔ بعد', next_weekly(now,0,8.0,15), 600+(7*1440)-600+465)
# کلاس یکشنبه ۸:۰۰ آلارم ۳۰ قبل → یکشنبه ۷:۳۰
check('کلاس فردا ۸:۰۰ منهای ۳۰', next_weekly(now,1,8.0,30), 1440+450)
# کلاس شنبه ۰۰:۱۰ آلارم ۳۰ قبل → جمعه ۲۳:۴۰ (روز قبل)
got = next_weekly(now,0,10/60,30)
check('آلارم ۳۰ قبلِ کلاس ۰۰:۱۰ → جمعه ۲۳:۴۰', hm(got), hm(6*1440+23*60+40))
# آلارم ۰ دقیقه = سرِ وقت
check('آلارم سرِ وقت', next_weekly(now,0,12.0,0), 720)
# آلارم ۱۲۰ دقیقه قبل (۲ ساعت)
check('کلاس شنبه ۱۴:۰۰ منهای ۱۲۰', next_weekly(now,0,14.0,120), 720)

print()
print('=== آلارم امتحان ===')
# امتحان ۱۰ مهر ۱۴۰۵ ساعت ۸:۰۰، آلارم ۶۰ دقیقه قبل → ۷:۰۰ همان روز
def exam_alarm(start_hour, mins):
    total = round(start_hour*60) - mins
    shift = 0
    while total < 0:
        total += 1440; shift -= 1
    return shift, total//60, total%60
check('امتحان ۸:۰۰ آلارم ۶۰ قبل', exam_alarm(8.0,60), (0,7,0))
check('امتحان ۸:۰۰ آلارم ۰ قبل', exam_alarm(8.0,0), (0,8,0))
check('امتحان ۰۰:۳۰ آلارم ۶۰ قبل → روز قبل', exam_alarm(0.5,60), (-1,23,30))
check('امتحان ۱۲:۳۰ آلارم ۹۰ قبل', exam_alarm(12.5,90), (0,11,0))

print()
print(f'{"همه پاس شدند" if fail==0 else str(fail)+" خطا"}')
sys.exit(1 if fail else 0)
