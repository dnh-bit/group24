import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

/// صدای آلارم: URI واقعی هر گزینه را از سمت نیتیو می‌گیرد.
///
/// چرا لازم است: اندروید صدا را روی کانال اعلان تنظیم می‌کند و صدای کانال
/// بعد از ساخت عوض نمی‌شود؛ پس برای هر انتخاب یک کانال جدا و یک URI مشخص
/// لازم داریم. اگر URI خالی بماند، پلاگین به `getDefaultUri` تکیه می‌کند که
/// روی بعضی گوشی‌ها null است و کانال کامل بی‌صدا ساخته می‌شود.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _ch = MethodChannel('cfu.group.plan/battery');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  String? _cachedApp;

  /// زنگ اختصاصی برنامه (res/raw/alarm.ogg)
  Future<String?> appAlarmUri() async {
    if (!_isAndroid) return null;
    if (_cachedApp != null) return _cachedApp;
    _cachedApp = await _invokeString('appAlarmSoundUri');
    return _cachedApp;
  }

  /// موسیقی انتخاب‌شدهٔ کاربر — اگر فایل پاک شده باشد null برمی‌گردد.
  Future<String?> customSoundUri() async {
    if (!_isAndroid) return null;
    final raw = SettingsService.instance.settings.customSoundUri;
    final candidate = raw.isNotEmpty ? raw : await _nativeCustomUri();
    if (candidate == null || candidate.isEmpty) return null;
    try {
      return await _ch.invokeMethod<String>('customSoundUri', {'uri': candidate});
    } catch (_) {
      return null;
    }
  }

  Future<String?> _nativeCustomUri() async {
    try {
      return await _ch.invokeMethod<String>('persistedCustomSoundUri');
    } catch (_) {
      return null;
    }
  }

  /// URI مؤثر برای هر نوع صدا. اگر «موسیقی خودم» انتخاب شده ولی فایلش رفته
  /// باشد، به زنگ برنامه برمی‌گردیم تا آلارم هرگز بی‌صدا نماند.
  Future<String?> uriFor(AlarmSound sound) async {
    switch (sound) {
      case AlarmSound.appAlarm:
        return appAlarmUri();
      case AlarmSound.custom:
        final c = await customSoundUri();
        return c ?? await appAlarmUri();
      case AlarmSound.vibrateOnly:
      case AlarmSound.silent:
        return null;
    }
  }

  /// یک بار پخش می‌کند تا کاربر بشنود.
  Future<bool> preview(String? uri) async {
    if (!_isAndroid || uri == null || uri.isEmpty) return false;
    try {
      return await _ch.invokeMethod<bool>('previewSound', {'uri': uri}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopPreview() async {
    if (!_isAndroid) return;
    try {
      await _ch.invokeMethod<bool>('stopPreview');
    } catch (_) {
      // بی‌خیال
    }
  }

  /// انتخابگر رسمی زنگ اندروید را باز می‌کند و URI انتخاب‌شده را برمی‌گرداند.
  ///
  /// چرا انتخابگر زنگ و نه FilePicker: URI فایل (file://) برای SystemUI
  /// قابل خواندن نیست و اعلان بی‌صدا می‌شود. انتخابگر زنگ یک URI پایدار
  /// content:// می‌دهد و کاربر از موسیقی‌های خودش هم می‌تواند انتخاب کند.
  Future<String?> pickCustomSound() async {
    if (!_isAndroid) return null;
    try {
      final uri = await _ch.invokeMethod<String>('pickCustomSound');
      if (uri != null && uri.isNotEmpty) return uri;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// نام نمایشی موسیقی انتخاب‌شده (نام فایل یا «موسیقی گوشی»).
  Future<String> customSoundLabel() async {
    if (!_isAndroid) return '';
    final uri = SettingsService.instance.settings.customSoundUri;
    if (uri.isEmpty) return '';
    try {
      final name = await _ch.invokeMethod<String>('soundDisplayName', {'uri': uri});
      return (name == null || name.isEmpty) ? 'موسیقی گوشی' : name;
    } catch (_) {
      return 'موسیقی گوشی';
    }
  }

  Future<void> clearCustomSound() async {
    if (!_isAndroid) return;
    try {
      await _ch.invokeMethod<bool>('clearCustomSound');
    } catch (_) {}
  }

  /// پاک کردن کش‌ها تا URIها و کانال‌ها با صدای تازه ساخته شوند.
  Future<void> refresh() async {
    _cachedApp = null;
  }

  Future<String?> _invokeString(String method) async {
    try {
      return await _ch.invokeMethod<String>(method);
    } catch (_) {
      return null;
    }
  }
}
