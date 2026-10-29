/// نسخهٔ برنامه در زمان کامپایل.
///
/// CI مقدار را با `--dart-define=APP_VERSION=<version>` می‌دهد؛ در بیلد محلی
/// مقدار پیش‌فرض استفاده می‌شود. برای اینکه «درباره» همیشه شمارهٔ واقعیِ
/// نسخهٔ نصب‌شده را نشان بدهد و کاربر بتواند با ما چک کند.
const String kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'نامشخص');
const bool kEmptyBuild = bool.fromEnvironment('EMPTY_DEFAULT');

/// «۰.۰.۱۱ (خالی)» یا «۰.۰.۱۱ (اصلی)»
String get versionLabel => '$kAppVersion${kEmptyBuild ? ' · نسخهٔ خالی' : ''}';
