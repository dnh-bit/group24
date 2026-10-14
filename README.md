# برنامه درسی 📱

اپ موبایل (Flutter) برنامه درسی · دانشگاه فرهنگیان · نیم‌سال اول ۱۴۰۵–۱۴۰۶

## امکانات
- صفحهٔ اول با گزینهٔ **«برنامه درسی»** (+ نمایش کلاس بعدی)
- **چند گروه درسی**: هر گروه برنامهٔ خودش رو داره؛ گروه فعال روی صفحهٔ اصلی، جدول هفتگی، امتحان‌ها و اعلان‌ها اثر می‌گذاره. افزودن، تغییر نام، انتخاب و حذف گروه (با گزینهٔ کپی درس‌ها از گروه فعلی)
- نمای **روزانه** (کارت هر کلاس، «در حال برگزاری»، کلاس‌های گذشته کم‌رنگ) و نمای **کل هفته** (همون جدول نسخهٔ وب، با اسکرول افقی و خط «الان»)
- جزئیات هر درس: استاد، واحد، جلسه‌ها، مکان، تاریخ امتحان
- **فصل امتحان‌ها** با شمارش معکوس روزها
- **تنظیمات:** اعلان ۱ تا ۱۵ دقیقه قبل از هر کلاس، یادآوری شب امتحان، اعلان آزمایشی
- همه‌چیز آفلاین؛ اعلان‌ها به وقت تهران و بعد از ری‌استارت گوشی هم می‌مونن

## بیلد با GitHub Actions (پیشنهادی)
فایل `.github/workflows/build-apk.yml` آماده‌ست. پروژه رو توی یه ریپو بذار (همین پوشه روت ریپو باشه) و push کن؛
خروجی APK توی بخش **Actions → Artifacts** با اسم `plan-apk` میاد. یا از تب Actions دستی `Run workflow` بزن.

## بیلد لوکال
```bash
flutter create --org cfu.group --project-name course_plan --platforms android .
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```
خروجی: `build/app/outputs/flutter-apk/app-release.apk`

> `flutter create .` فایل‌های موجود رو دست نمی‌زنه. ⚠️ در این ریپو **`build.gradle.kts` نگذارید** — `flutter create` نسخهٔ گرووی (`build.gradle`) می‌سازه و اگر هر دو باشند گریدل `.kts` را نادیده می‌گیرد و تنظیمات امضا بی‌اثر می‌شود.

## ویرایش برنامه
برنامهٔ اولیه توی `lib/data/default_schedule.dart` هست. ولی کاربر می‌تونه از داخل اپ (دکمهٔ ✎ بالای صفحهٔ برنامه) درس، جلسه، امتحان، رنگ و یادداشت رو ویرایش کنه؛ این تغییرات روی گوشی ذخیره می‌شن. پشتیبان JSON هم می‌شه کپی/بازگردانی کرد (کامل یا فقط گروه فعال).

## ساختار
```
lib/
  main.dart
  theme.dart · utils.dart
  jalali.dart                     ← تبدیل تاریخ شمسی/میلادی
  data/models.dart · schedule_store.dart · default_schedule.dart
  screens/editor/                 ← گروه‌ها، ویرایش درس‌ها، فرم درس، جلسه، انتخاب تاریخ
  services/notification_service.dart  ← زمان‌بندی اعلان‌ها
  services/settings_service.dart      ← ذخیرهٔ تنظیمات
  screens/home_screen.dart · schedule_screen.dart · settings_screen.dart
  widgets/star.dart
assets/fonts  (وزیرمتن + لاله‌زار)   assets/icon
```
