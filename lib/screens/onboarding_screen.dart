import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/battery_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../utils.dart';

/// اسلاید خوش‌آمدگویی — فقط بار اول بعد از نصب باز می‌شود.
///
/// چهار صفحه: خوش‌آمد، انتخاب حالت اعلان درس‌ها، اجازهٔ اعلان، باتری.
/// هر صفحه دکمهٔ «رد کردن» دارد؛ هیچ‌چیز اجباری نیست و همهٔ انتخاب‌ها بعداً
/// در تنظیمات قابل تغییرند.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// بعد از پایان (یا رد کردن) صدا زده می‌شود.
  final VoidCallback? onDone;

  /// آیا این اسلاید باید نشان داده شود؟
  static bool shouldShow() => !SettingsService.instance.settings.onboarded;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _svc = SettingsService.instance;
  final _notif = NotificationService.instance;

  int _page = 0;
  static const _total = 4;

  late CourseAlert _alert = _svc.settings.defaultAlert;
  bool _classReminders = _svc.settings.classReminders;
  bool _examReminders = _svc.settings.examReminders;
  bool _fullScreen = _svc.settings.fullScreenAlarm;
  bool _busy = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _total - 1) {
      await _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _svc.update(_svc.settings.copyWith(
      onboarded: true,
      defaultAlert: _alert,
      classReminders: _classReminders,
      examReminders: _examReminders,
      fullScreenAlarm: _fullScreen,
    ));
    await _notif.reschedule();
    if (!mounted) return;
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── نوار بالا: شمارهٔ صفحه + رد کردن ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _total; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(left: 5),
                      width: i == _page ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.saffron : AppColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  const Spacer(),
                  if (_page < _total - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('رد کردن',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                ],
              ),
            ),

            // ── صفحه‌ها ──
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _WelcomePage(),
                  _AlertChoicePage(
                    value: _alert,
                    onChanged: (v) => setState(() => _alert = v),
                    classReminders: _classReminders,
                    examReminders: _examReminders,
                    onClass: (v) => setState(() => _classReminders = v),
                    onExam: (v) => setState(() => _examReminders = v),
                    fullScreen: _fullScreen,
                    onFullScreen: (v) => setState(() => _fullScreen = v),
                  ),
                  _PermissionPage(
                    onAllow: () async {
                      await _notif.requestPermission();
                      if (_isAndroid) await _notif.requestExactAlarms();
                      if (mounted) {
                        setState(() {});
                        await _pages.nextPage(
                            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                      }
                    },
                  ),
                  _BatteryPage(onDone: _finish),
                ],
              ),
            ),

            // ── پایین: دکمهٔ اصلی ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.saffron,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          _page == _total - 1 ? 'شروع کنیم' : 'بعدی',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ ۱. خوش‌آمد ═══════════════════

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      icon: Icons.event_note_rounded,
      title: 'برنامهٔ درسی',
      body: Column(
        children: [
          const Text(
            'همراهِ روزهای دانشگاهت',
            style: TextStyle(fontFamily: kTitleFont, fontSize: 26, color: AppColors.olive),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text(
            'برنامهٔ هفتگی کلاس‌ها و تاریخ امتحان‌ها را یک‌جا داشته باش.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.9, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          const _Feature(icon: Icons.alarm_rounded, text: 'آلارم قبل از هر کلاس و امتحان'),
          const _Feature(icon: Icons.groups_2_rounded, text: 'چند برنامهٔ جدا برای هر گروه'),
          const _Feature(icon: Icons.wifi_off_rounded, text: 'کاملاً آفلاین، بدون تبلیغ'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.saffron.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'در سه گام کوتاه تنظیمش می‌کنیم — کمتر از یک دقیقه.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.saffron, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ ۲. انتخاب حالت اعلان ═══════════════════

class _AlertChoicePage extends StatelessWidget {
  final CourseAlert value;
  final ValueChanged<CourseAlert> onChanged;
  final bool classReminders;
  final bool examReminders;
  final ValueChanged<bool> onClass;
  final ValueChanged<bool> onExam;
  final bool fullScreen;
  final ValueChanged<bool> onFullScreen;

  const _AlertChoicePage({
    required this.value,
    required this.onChanged,
    required this.classReminders,
    required this.examReminders,
    required this.onClass,
    required this.onExam,
    required this.fullScreen,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      icon: Icons.notifications_active_rounded,
      title: 'چطور خبرت کنم؟',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'این حالت پیش‌فرض همهٔ درس‌هاست. بعداً می‌توانی هر درس را جدا عوض کنی.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.8, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          _ChoiceCard(
            selected: value == CourseAlert.alarm,
            onTap: () => onChanged(CourseAlert.alarm),
            icon: Icons.alarm_on_rounded,
            title: 'آلارم',
            subtitle: 'تمام‌صفحه با زنگ و لرزش — مثل ساعت‌زنگ',
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            selected: value == CourseAlert.notice,
            onTap: () => onChanged(CourseAlert.notice),
            icon: Icons.notifications_none_rounded,
            title: 'فقط اعلان',
            subtitle: 'یک نوتیفیکیشن ساده بدون زنگ',
          ),
          const SizedBox(height: 20),
          const _MiniDivider('چه چیزهایی یادآوری شوند؟'),
          const SizedBox(height: 6),
          _ToggleRow(label: 'کلاس‌ها', value: classReminders, onChanged: onClass),
          _ToggleRow(label: 'امتحان‌ها', value: examReminders, onChanged: onExam),
          if (value == CourseAlert.alarm)
            _ToggleRow(
              label: 'روی صفحهٔ قفل هم بیاید',
              value: fullScreen,
              onChanged: onFullScreen,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════ ۳. اجازهٔ اعلان ═══════════════════

class _PermissionPage extends StatelessWidget {
  final Future<void> Function() onAllow;
  const _PermissionPage({required this.onAllow});

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      icon: Icons.notifications_paused_rounded,
      title: 'اجازهٔ اعلان',
      body: Column(
        children: [
          const Icon(Icons.notifications_active_rounded, size: 68, color: AppColors.saffron),
          const SizedBox(height: 20),
          const Text(
            'برای اینکه آلارم‌ها برسند، اندروید باید اجازه بدهد.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.9),
          ),
          const SizedBox(height: 10),
          const Text(
            'اندروید دو اجازه می‌خواهد: «نمایش اعلان» و «آلارم دقیق». '
            'بدون دومی، آلارم ممکن است چند دقیقه دیر بیاید.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.muted),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAllow,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('اجازه می‌دهم'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'اگر الان نخواستی، بعداً از تنظیمات ← سیستم هم می‌شود.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ ۴. باتری ═══════════════════

class _BatteryPage extends StatefulWidget {
  final Future<void> Function() onDone;
  const _BatteryPage({required this.onDone});

  @override
  State<_BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<_BatteryPage> with WidgetsBindingObserver {
  bool _ok = true;
  String _manufacturer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final ok = await BatteryService.instance.isIgnoringBatteryOptimizations();
    final info = await BatteryService.instance.deviceInfo();
    if (!mounted) return;
    setState(() {
      _ok = ok;
      _manufacturer = (info['manufacturer'] ?? '').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final aggressive = BatteryService.aggressiveVendor(_manufacturer);
    return _PageShell(
      icon: Icons.battery_charging_full_rounded,
      title: 'باتری',
      body: Column(
        children: [
          Icon(_ok ? Icons.battery_full_rounded : Icons.battery_alert_rounded,
              size: 68, color: _ok ? AppColors.olive : AppColors.saffron),
          const SizedBox(height: 20),
          Text(
            _ok ? 'آلارم‌ها آزادند ✦' : 'یک تنظیم کوچک مانده',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kTitleFont, fontSize: 22, color: AppColors.olive),
          ),
          const SizedBox(height: 12),
          Text(
            aggressive
                ? 'گوشی ${BatteryService.vendorLabel(_manufacturer)} ممکن است اپ را در پس‌زمینه '
                    'بخواباند و آلارم را عقب بیندازد. با یک لمس اجازه بده.'
                : 'اگر آلارم دیر آمد، اجازه بده اپ در پس‌زمینه بیدار بماند.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.9, color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          if (kIsWeb || Platform.isAndroid)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final opened = await BatteryService.instance.openBatterySettings();
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('این صفحه روی این گوشی پیدا نشد؛ از تنظیمات ← سیستم امتحان کن.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.battery_charging_full_rounded),
                label: Text(_ok ? 'مدیریت باتری' : 'آزاد کردن باتری'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: widget.onDone,
            child: const Text('رد کن و برو داخل',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════ اجزای مشترک ═══════════════════

class _PageShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;

  _PageShell({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.saffron.withAlpha(24),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: AppColors.saffron),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kTitleFont, fontSize: 30, color: AppColors.olive),
          ),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.saffron.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.saffron),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13.5, height: 1.6, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.saffron.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.saffron : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: selected ? AppColors.saffron : AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: selected ? AppColors.saffron : null,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.saffron : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.saffron,
      title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  final String text;
  const _MiniDivider(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(text,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
