import 'package:flutter_test/flutter_test.dart';

import 'package:course_plan/services/battery_service.dart';

/// تشخیص گوشی‌هایی که اپ را در پس‌زمینه می‌خوابانند. اگر این منطق خراب شود،
/// کاربر گوشی شیائومی/هواوی راهنمای درست را نمی‌بیند و آلارمش دیر می‌آید.
void main() {
  group('تشخیص سازندهٔ سخت‌گیر', () {
    test('شیائومی و زیرشاخه‌ها', () {
      expect(BatteryService.aggressiveVendor('Xiaomi'), isTrue);
      expect(BatteryService.aggressiveVendor('Redmi'), isTrue);
      expect(BatteryService.aggressiveVendor('POCO'), isTrue);
      expect(BatteryService.aggressiveVendor('xiaomi'), isTrue);
    });

    test('هواوی و آنر', () {
      expect(BatteryService.aggressiveVendor('HUAWEI'), isTrue);
      expect(BatteryService.aggressiveVendor('Huawei'), isTrue);
      expect(BatteryService.aggressiveVendor('HONOR'), isTrue);
    });

    test('سامسونگ، اوپو، ریلمی، وان‌پلاس، ویوو', () {
      expect(BatteryService.aggressiveVendor('samsung'), isTrue);
      expect(BatteryService.aggressiveVendor('OPPO'), isTrue);
      expect(BatteryService.aggressiveVendor('realme'), isTrue);
      expect(BatteryService.aggressiveVendor('OnePlus'), isTrue);
      expect(BatteryService.aggressiveVendor('vivo'), isTrue);
      expect(BatteryService.aggressiveVendor('iQOO'), isTrue);
    });

    test('گوگل و موتورولا در فهرست نیستند', () {
      expect(BatteryService.aggressiveVendor('Google'), isFalse);
      expect(BatteryService.aggressiveVendor('motorola'), isFalse);
    });

    test('رشتهٔ خالی کرش نمی‌کند', () {
      expect(BatteryService.aggressiveVendor(''), isFalse);
    });
  });

  group('برچسب فارسی سازنده', () {
    test('نام‌های فارسی درست', () {
      expect(BatteryService.vendorLabel('Xiaomi'), contains('شیائومی'));
      expect(BatteryService.vendorLabel('Redmi'), contains('شیائومی'));
      expect(BatteryService.vendorLabel('HUAWEI'), contains('هواوی'));
      expect(BatteryService.vendorLabel('samsung'), contains('سامسونگ'));
      expect(BatteryService.vendorLabel('OPPO'), contains('اوپو'));
      expect(BatteryService.vendorLabel('vivo'), contains('ویوو'));
    });

    test('سازندهٔ ناشناس همان نام اصلی را برمی‌گرداند', () {
      expect(BatteryService.vendorLabel('Google'), 'Google');
      expect(BatteryService.vendorLabel(''), '');
    });
  });

  group('رفتار امن روی تست (بدون پل اندروید)', () {
    test('در تست، باتری «آزاد» فرض می‌شود تا مزاحم کاربر نشود', () async {
      // در flutter_test پلتفرم اندروید نیست → نباید استثنا بدهد
      expect(await BatteryService.instance.isIgnoringBatteryOptimizations(), isTrue);
    });

    test('باز کردن صفحه‌های تنظیمات در تست false می‌دهد نه استثنا', () async {
      expect(await BatteryService.instance.openBatterySettings(), isFalse);
      expect(await BatteryService.instance.openAutoStart(), isFalse);
      expect(await BatteryService.instance.openAppSettings(), isFalse);
    });

    test('deviceInfo در تست نقشهٔ خالی می‌دهد', () async {
      final info = await BatteryService.instance.deviceInfo();
      expect(info, isEmpty);
    });
  });
}
