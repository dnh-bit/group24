import 'dart:async';

import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../data/models.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/star.dart';
import 'editor/groups_screen.dart';
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
          groupCards.add(_MainOption(
            title: g.name,
            subtitle: next == null
                ? (g.courses.isEmpty
                    ? 'این گروه هنوز درسی نداره — از ویرایشگر اضافه کن'
                    : 'برنامهٔ هفتگی و تاریخ امتحان‌ها')
                : '${next.ongoing ? 'الان سر کلاسی' : 'کلاس بعدی'}: ${next.ref.course.shortName}\n'
                    '${next.whenLabel} · ${fmtTime(next.ref.session.start)} · ${next.ref.session.room}',
            onTap: () {
              store.selectGroup(g.id);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              );
            },
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'سلام ✦',
                          style: TextStyle(fontFamily: kTitleFont, fontSize: 40, color: AppColors.saffron, height: 1.1),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'گروه‌های درسی',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GroupsScreen()),
                        ),
                        icon: const Icon(Icons.groups_rounded),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'تنظیمات',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                        icon: const Icon(Icons.settings_rounded),
                      ),
                    ],
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
                    // ردیف چیپ‌های گروه — با ضربه، گروه فعال عوض می‌شه
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final g in store.groups)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: ChoiceChip(
                                selected: g.id == store.activeGroupId,
                                label: Text(
                                  g.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: g.id == store.activeGroupId ? Colors.white : null,
                                  ),
                                ),
                                selectedColor: AppColors.saffron,
                                showCheckmark: false,
                                onSelected: (_) => store.selectGroup(g.id),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.settings_suggest_rounded, size: 16),
                              label: const Text('مدیریت', style: TextStyle(fontSize: 12.5)),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GroupsScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // برای هر گروه درسی یک کارت با برنامهٔ خودش
                    ...groupCards,
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
  const _MainOption({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFF8A1F), AppColors.saffron, Color(0xFFE85D00)],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.saffron.withAlpha(90), blurRadius: 30, offset: const Offset(0, 14)),
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: AppColors.saffron),
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
