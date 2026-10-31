import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// وضعیت بهینه‌سازی باتری و دسترسی‌های سازنده‌های گوشی.
///
/// هیچ چیز از این‌ها برای کار کردن اپ لازم نیست؛ فقط برای این است که
/// آلارم روی گوشی‌هایی که اپ را در پس‌زمینه می‌خوابانند (شیائومی، هواوی،
/// سامسونگ و…) هم سر وقت بیاید. اپ خودش هیچ تنظیمی را عوض نمی‌کند و فقط
/// صفحهٔ درست را باز می‌کند تا کاربر خودش تصمیم بگیرد.
class BatteryService {
  BatteryService._();
  static final BatteryService instance = BatteryService._();

  static const _ch = MethodChannel('cfu.group.plan/battery');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// گوشی‌هایی که معروف‌اند اپ را در پس‌زمینه می‌خوابانند و تنظیم اضافه دارند.
  static bool aggressiveVendor(String manufacturer) {
    final m = manufacturer.toLowerCase();
    const known = [
      'xiaomi', 'redmi', 'poco', // MIUI / HyperOS
      'huawei', 'honor',
      'samsung',
      'oppo', 'realme', 'oneplus',
      'vivo', 'iqoo',
      'asus', 'letv', 'leeco', 'nokia', 'meizu', 'tecno', 'infinix', 'itel',
    ];
    return known.any(m.contains);
  }

  /// نام فارسی سازنده برای راهنما
  static String vendorLabel(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return 'شیائومی / ردمی / پوکو';
    }
    if (m.contains('huawei') || m.contains('honor')) return 'هواوی / آنر';
    if (m.contains('samsung')) return 'سامسونگ';
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) return 'اوپو / ریلمی / وان‌پلاس';
    if (m.contains('vivo') || m.contains('iqoo')) return 'ویوو / آیکو';
    if (m.contains('asus')) return 'ایسوس';
    if (m.contains('nokia')) return 'نوکیا';
    return manufacturer;
  }

  /// آیا اپ از بهینه‌سازی باتری مستثنا شده؟ (true = آلارم‌ها آزادند)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _ch.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true; // اگر پل آماده نبود، مزاحم کاربر نشو
    }
  }

  /// باز کردن صفحهٔ بهینه‌سازی باتری
  Future<bool> openBatterySettings() async {
    if (!_isAndroid) return false;
    return await _invoke('openBatteryOptimizationSettings');
  }

  /// باز کردن صفحهٔ Autostart مخصوص سازندهٔ گوشی
  Future<bool> openAutoStart() async {
    if (!_isAndroid) return false;
    return await _invoke('openAutoStartSettings');
  }

  /// صفحهٔ تنظیمات خود اپ (برای اجازهٔ اعلان یا باتری)
  Future<bool> openAppSettings() async {
    if (!_isAndroid) return false;
    return await _invoke('openAppSettings');
  }

  /// اطلاعات گوشی برای متن راهنما
  Future<Map<String, dynamic>> deviceInfo() async {
    if (!_isAndroid) return const {};
    try {
      final raw = await _ch.invokeMapMethod<String, dynamic>('deviceInfo');
      return raw ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<bool> _invoke(String method) async {
    try {
      return await _ch.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}
