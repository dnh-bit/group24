import 'dart:async';

import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../data/models.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/star.dart';
import 'editor/groups_screen.dart';
import 'editor/widgets.dart' show toast;
import 'schedule_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.firstRunSetup();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ScheduleStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final groupCards = <Widget>[];
        for (final g in store.groups) {
          final next = store.findNextFor(g, _now);
          final isActive = g.id == store.activeGroupId;
          groupCards.add(_MainOption(
            title: g.name,
            active: isActive,
            subtitle: next == null
                ? (g.courses.isEmpty
                    ? 'این گروه هنوز درسی نداره — از مدیریت گروه‌ها اضافه کن'
                    : 'برنامهٔ هفتگی و تاریخ امتحان‌ها')
                : '${next.ongoing ? 'الان سر کلاسی' : 'کلاس بعدی'}: ${next.ref.course.shortName}\n'
                    '${next.whenLabel} · ${fmtTime(next.ref.session.start)} · ${next.ref.session.room}',
            // ضربه روی گروهِ غیرفعال → فعال می‌شه؛ ضربه دوباره → صفحهٔ برنامه
            onTap: () {
              if (isActive) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                );
              } else {
                store.selectGroup(g.id);
                toast(context, 'گروه فعال شد: ${g.name}');
              }
            },
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ));
          groupCards.add(const SizedBox(height: 16));
        }
        final isEmptyMode = store.groups.isEmpty;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'سلام ✦',
                    style: TextStyle(fontFamily: kTitleFont, fontSize: 40, color: AppColors.saffron, height: 1.1),
                  ),
                  Text(
                    isEmptyMode ? 'برنامه درسی' : 'برنامه درسی · دانشگاه فرهنگیان',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  if (isEmptyMode) ...[
                    // نسخهٔ خالی: هیچ گروهی نیست — فقط دعوت به ساختن گروه
                    _MainOption(
                      title: 'افزودن گروه',
                      subtitle: 'اولین گروه درسی‌ت رو بساز — از صفر، از فایل پشتیبان، '
                          'از متن، یا با دستیار هوشمند. بعدش همین‌جا کارت برنامه‌ت میاد.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GroupsScreen()),
                      ),
                    ),
                  ] else ...[
                    // برای هر گروه درسی یک کارت: فعال = نارنجی، غیرفعال = خاکستری
                    ...groupCards,
                    // مدیریت گروه‌ها — دکمهٔ واضح زیر کارت‌ها
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.olive,
                              side: const BorderSide(color: AppColors.olive, width: 1.4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const GroupsScreen()),
                            ),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('مدیریت گروه‌ها',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // تنظیمات (اعلان‌ها و…) — دسترسی کوچک کنار دکمهٔ مدیریت
                        IconButton.outlined(
                          tooltip: 'تنظیمات',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.olive,
                            side: const BorderSide(color: AppColors.olive, width: 1.4),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ),
                          icon: const Icon(Icons.settings_rounded),
                        ),
                      ],
                    ),
                  ],
                  if (!isEmptyMode)
                    Text(
                      'نیم‌سال اول ۱۴۰۵–۱۴۰۶',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MainOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final bool active;
  const _MainOption({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onOpen,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    // فعال = نارنجی پویا؛ غیرفعال = خاکستری ساکن
    final gradient = active
        ? const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFF8A1F), AppColors.saffron, Color(0xFFE85D00)],
          )
        : const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFB9BEB4), Color(0xFF9AA096), Color(0xFF8B9186)],
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: active ? AppColors.saffron.withAlpha(90) : Colors.black26,
                blurRadius: active ? 30 : 12,
                offset: Offset(0, active ? 14 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
            children: [
              const PositionedDirectional(
                start: -30,
                bottom: -40,
                child: SpinningStar(size: 150, color: Color(0x33FFFFFF), hole: Color(0xFFFF7A0D)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: kTitleFont,
                              fontSize: 36,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onOpen,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, color: AppColors.saffron),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
