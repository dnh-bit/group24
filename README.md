# برنامه گروه ۲۴ 📱

اپ موبایل (Flutter) برنامهٔ هفتگی گروه ۲۴ · دانشگاه فرهنگیان · نیم‌سال اول ۱۴۰۵–۱۴۰۶

## امکانات
- صفحهٔ اول با گزینهٔ **«برنامه گروه ۲۴»** (+ نمایش کلاس بعدی)
- نمای **روزانه** (کارت هر کلاس، «در حال برگزاری»، کلاس‌های گذشته کم‌رنگ) و نمای **کل هفته** (همون جدول نسخهٔ وب، با اسکرول افقی و خط «الان»)
- جزئیات هر درس: استاد، واحد، جلسه‌ها، مکان، تاریخ امتحان
- **فصل امتحان‌ها** با شمارش معکوس روزها
- **تنظیمات:** اعلان ۱ تا ۱۵ دقیقه قبل از هر کلاس، یادآوری شب امتحان، اعلان آزمایشی
- همه‌چیز آفلاین؛ اعلان‌ها به وقت تهران و بعد از ری‌استارت گوشی هم می‌مونن

## بیلد با GitHub Actions (پیشنهادی)
فایل `.github/workflows/build-apk.yml` آماده‌ست. پروژه رو توی یه ریپو بذار (همین پوشه روت ریپو باشه) و push کن؛
خروجی APK توی بخش **Actions → Artifacts** با اسم `group24-apk` میاد. یا از تب Actions دستی `Run workflow` بزن.

## بیلد لوکال
```bash
flutter create --org ir.cfu --project-name group24 --platforms android .
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```
خروجی: `build/app/outputs/flutter-apk/app-release.apk`

> `flutter create .` فایل‌های موجود (مثل `AndroidManifest.xml` و `build.gradle.kts`) رو دست نمی‌زنه.

## ویرایش برنامه
برنامهٔ اولیه توی `lib/data/default_schedule.dart` هست. ولی کاربر می‌تونه از داخل اپ (دکمهٔ ✎ بالای صفحهٔ برنامه) درس، جلسه، امتحان، رنگ و یادداشت رو ویرایش کنه؛ این تغییرات روی گوشی ذخیره می‌شن. پشتیبان JSON هم می‌شه کپی/بازگردانی کرد.

## ساختار
```
lib/
  main.dart
  theme.dart · utils.dart
  jalali.dart                     ← تبدیل تاریخ شمسی/میلادی
  data/models.dart · schedule_store.dart · default_schedule.dart
  screens/editor/                 ← ویرایش درس‌ها، فرم درس، جلسه، انتخاب تاریخ
  services/notification_service.dart  ← زمان‌بندی اعلان‌ها
  services/settings_service.dart      ← ذخیرهٔ تنظیمات
  screens/home_screen.dart · schedule_screen.dart · settings_screen.dart
  widgets/star.dart
assets/fonts  (وزیرمتن + لاله‌زار)   assets/icon
```
