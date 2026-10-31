import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/schedule_store.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../version.dart';
import 'ai_assistant_screen.dart';
import 'editor/groups_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _svc = SettingsService.instance;
  final _notif = NotificationService.instance;
  late double _minutes = _svc.settings.minutesBefore.toDouble();
  bool _exactOk = true;
  // اندروید ۱۴+ اجازهٔ جدا برای آلارم تمام‌صفحه می‌خواهد
  bool _fullScreenOk = !NotificationService.needsFullScreenPermission;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPerms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // وقتی کاربر از صفحهٔ تنظیمات اندروید برمی‌گرده، دوباره چک کن
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPerms().then((_) => _notif.reschedule());
    }
  }

  Future<void> _checkPerms() async {
    final exact = await _notif.canScheduleExact();
    if (!mounted) return;
    setState(() => _exactOk = exact);
  }

  /// درخواست اجازهٔ آلارم تمام‌صفحه (اندروید ۱۴+)
  Future<void> _askFullScreen() async {
    final ok = await _notif.requestFullScreen();
    if (!mounted) return;
    setState(() => _fullScreenOk = ok);
    _toast(ok ? 'اجازهٔ آلارم تمام‌صفحه داده شد ✦' : 'اجازه داده نشد؛ اعلان معمولی می‌آید.');
  }

  Future<void> _save(AppSettings s) async {
    await _svc.update(s);
    await _notif.reschedule();
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _toggleClass(bool v) async {
    if (v) {
      final granted = await _notif.requestPermission();
      if (!granted) {
        _toast('اجازهٔ اعلان داده نشد. از تنظیمات گوشی فعالش کن.');
      }
    }
    await _save(_svc.settings.copyWith(classReminders: v));
    if (v) _toast('یادآوری کلاس‌ها روشن شد ✦');
  }

  Future<void> _toggleExam(bool v) async {
    if (v) await _notif.requestPermission();
    await _save(_svc.settings.copyWith(examReminders: v));
  }

  Future<void> _toggleCancelOneHour(bool v) async {
    await _save(_svc.settings.copyWith(cancelOneHourClasses: v));
    _toast(v ? 'کلاس‌های تک‌ساعته لغو شدند (برگزار نمی‌شوند)' : 'کلاس‌های تک‌ساعته فعال شدند (برگزار می‌شوند)');
  }

  /// انتخاب نوع صدا با شیت پایین
  Future<void> _pickSound(AppSettings s) async {
    final picked = await showModalBottomSheet<AlarmSound>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('صدای آلارم', style: TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
              ),
            ),
            for (final v in AlarmSound.values)
              RadioListTile<AlarmSound>(
                value: v,
                groupValue: s.alarmSound,
                activeColor: AppColors.saffron,
                title: Text(v.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(v.hint, style: const TextStyle(fontSize: 12.5)),
                onChanged: (x) => Navigator.pop(ctx, x),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == s.alarmSound) return;
    await _save(s.copyWith(alarmSound: picked));
    _toast('صدای آلارم: ${picked.label}');
  }

  /// انتخاب دقیقهٔ آلارم امتحان
  Future<void> _pickExamMinutes(AppSettings s) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('چند دقیقه قبل از امتحان؟',
                    style: TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
              ),
            ),
            for (final v in const [0, 15, 30, 45, 60, 90, 120])
              RadioListTile<int>(
                value: v,
                groupValue: s.examAlarmMinutes,
                activeColor: AppColors.saffron,
                title: Text(
                  v == 0 ? 'سرِ وقت دقیق' : '${fa(v)} دقیقه قبل',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onChanged: (x) => Navigator.pop(ctx, x),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _save(s.copyWith(examAlarmMinutes: picked));
  }

  @override
  Widget build(BuildContext context) {
    final s = _svc.settings;
    final m = _minutes.round();
    final store = ScheduleStore.instance;
    final notifGroup = store.groupForNotifications();
    final notifNext = store.findNextFor(notifGroup, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _SectionTitle('اعلان‌ها'),
          _Card(
            children: [
              SwitchListTile(
                value: s.classReminders,
                onChanged: _toggleClass,
                secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.saffron),
                title: const Text('یادآوری قبل از کلاس', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('قبل از شروع هر کلاس یه اعلان می‌گیری'),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: s.classReminders ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !s.classReminders,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('چند دقیقه قبل؟', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.saffron,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(m == 0 ? 'سرِ وقت' : '${fa(m)} دقیقه',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        Slider(
                          value: _minutes,
                          min: SettingsService.minMinutes.toDouble(),
                          max: SettingsService.maxMinutes.toDouble(),
                          divisions: SettingsService.maxMinutes,
                          label: m == 0 ? 'سرِ وقت' : '${fa(m)} دقیقه',
                          activeColor: AppColors.saffron,
                          onChanged: (v) => setState(() => _minutes = v),
                          onChangeEnd: (v) => _save(s.copyWith(minutesBefore: v.round())),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final q in const [0, 5, 10, 15, 20, 30, 45, 60])
                              ChoiceChip(
                                label: Text(q == 0 ? 'سرِ وقت' : '${fa(q)} دقیقه'),
                                selected: m == q,
                                onSelected: (_) {
                                  setState(() => _minutes = q.toDouble());
                                  _save(s.copyWith(minutesBefore: q));
                                },
                              ),
                          ],
                        ),
                        if (notifNext != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'مثلاً برای «${notifNext.ref.course.shortName}» ساعت '
                            '${fmtTime(notifNext.ref.session.start - m / 60)} خبرت می‌کنم.',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            children: [
              SwitchListTile(
                value: s.examReminders,
                onChanged: _toggleExam,
                secondary: const Icon(Icons.event_note_rounded, color: AppColors.olive),
                title: const Text('یادآوری امتحان‌ها', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('شب قبل ساعت ۲۰:۰۰ + آلارم قبل از شروع'),
              ),
              if (s.examReminders) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.alarm_rounded, color: AppColors.olive),
                  title: const Text('آلارم قبل از امتحان', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    s.examAlarmMinutes == 0
                        ? 'سرِ وقت شروع امتحان آلارم می‌زند'
                        : '${fa(s.examAlarmMinutes)} دقیقه قبل از امتحان',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => _pickExamMinutes(s),
                ),
                SwitchListTile(
                  value: s.examFullAlarm,
                  onChanged: (v) => _save(s.copyWith(examFullAlarm: v)),
                  secondary: const Icon(Icons.notifications_paused_rounded, color: AppColors.olive),
                  title: const Text('آلارم امتحان تمام‌صفحه باشد', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('اگر خاموش باشد فقط یک اعلان ساده می‌آید'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('آلارم'),
          _Card(
            children: [
              SwitchListTile(
                value: s.fullScreenAlarm,
                onChanged: (v) => _save(s.copyWith(fullScreenAlarm: v)),
                secondary: const Icon(Icons.phonelink_ring_rounded, color: AppColors.saffron),
                title: const Text('آلارم تمام‌صفحه', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('روی صفحهٔ قفل هم می‌آید و زنگ می‌زند، نه فقط یک اعلان ساده'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.music_note_rounded, color: AppColors.saffron),
                title: const Text('صدای آلارم', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(s.alarmSound.label),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _pickSound(s),
              ),
              SwitchListTile(
                value: s.vibrate,
                onChanged: (v) => _save(s.copyWith(vibrate: v)),
                secondary: const Icon(Icons.vibration_rounded, color: AppColors.saffron),
                title: const Text('لرزش همراه آلارم', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('گوشی هم می‌لرزد تا متوجه بشی'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: AppColors.saffron),
                title: const Text('آلارم آزمایشی', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('همین حالا یک آلارم واقعی بفرست و ببین چه شکلی است'),
                onTap: () async {
                  await _notif.requestPermission();
                  await _notif.showTest(m);
                },
              ),
            ],
          ),
          if (_isAndroid && (!_exactOk || !_fullScreenOk)) ...[
            const SizedBox(height: 12),
            _Card(
              children: [
                if (!_exactOk)
                  ListTile(
                    leading: const Icon(Icons.alarm_on_rounded, color: AppColors.saffron),
                    title: const Text('دقیق سر وقت بیاد', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'برای اینکه آلارم دقیقاً همون دقیقه بیاد، اجازهٔ «آلارم و یادآوری» رو بده.'),
                    trailing: FilledButton(
                      onPressed: () => _notif.requestExactAlarms(),
                      child: const Text('اجازه'),
                    ),
                  ),
                if (!_fullScreenOk)
                  ListTile(
                    leading: const Icon(Icons.fullscreen_rounded, color: AppColors.saffron),
                    title: const Text('نمایش تمام‌صفحه', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'اندروید ۱۴+ برای آلارم تمام‌صفحه اجازهٔ جدا می‌خواهد. بدون آن، اعلان معمولی می‌آید.'),
                    trailing: FilledButton(
                      onPressed: _askFullScreen,
                      child: const Text('اجازه'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('کدام درس‌ها اعلان بگیرند'),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: const [
                    Icon(Icons.tune_rounded, color: AppColors.saffron),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('انتخاب درس و جلسه', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'اعلان‌ها از برنامهٔ «${notifGroup.name}» می‌آیند. '
                  'هر درس را می‌توانی کامل خاموش کنی یا دقیقهٔ آلارم خودش را بدهی.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6),
                ),
              ),
              if (notifGroup.courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text('این گروه درسی ندارد.', style: TextStyle(color: AppColors.muted)),
                ),
              for (final c in notifGroup.courses)
                _CourseAlarmTile(course: c, groupId: notifGroup.id, onChanged: () => setState(() {})),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.groups_2_rounded, color: AppColors.saffron),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('برنامهٔ اعلان‌ها',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'یادآوری‌ها فقط از «یک» برنامه می‌آد — کدوم گروه بهت اعلان بده؟',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              for (final g in store.groups)
                Builder(builder: (context) {
                  final selected = s.notifGroupId.isEmpty ? store.activeGroupId : s.notifGroupId;
                  return RadioListTile<String>(
                    value: g.id,
                    groupValue: selected,
                    onChanged: (v) => _save(s.copyWith(notifGroupId: v)),
                    activeColor: AppColors.saffron,
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${fa(g.courses.length)} درس · ${fa(g.totalUnits)} واحد',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('گروه‌های درسی'),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.groups_rounded, color: AppColors.saffron),
                title: const Text('مدیریت گروه‌ها', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'گروه فعال: «${store.activeGroup.name}» · '
                  '${fa(store.groups.length)} گروه — '
                  'انتخاب، افزودن، ویرایش و حذف گروه‌ها',
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.saffron),
                title: const Text('دستیار هوشمند', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'برنامهٔ دانشگاهت رو به چت‌بات (ChatGPT و…) بده تا JSON آماده بسازه؛ '
                  'اینجا پرامپت آماده می‌گیری و خروجی رو داخل اپ وارد می‌کنی. '
                  'اپ هیچ داده‌ای به هیچ سرویسی نمی‌فرسته.',
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('کلاس‌ها'),
          _Card(
            children: [
              SwitchListTile(
                value: s.cancelOneHourClasses,
                onChanged: _toggleCancelOneHour,
                secondary: const Icon(Icons.timer_off_outlined, color: AppColors.saffron),
                title: const Text('لغو کلاس‌های تک‌ساعته', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'کلاس‌های یک‌ساعته برگزار نشوند و از جدول، یادآوری‌ها و تداخل‌ها حذف شوند (ویژهٔ دانشگاه فرهنگیان)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('درباره'),
          _Card(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('دربارهٔ برنامه درسی', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'برنامهٔ هفتگی کلاس‌ها و تاریخ امتحان‌ها با آلارم و یادآوری.\n'
                  '• گروه‌ها: هر گروه یه برنامهٔ جداست؛ گروه فعال توی صفحهٔ اصلی و جدول نشون داده می‌شه.\n'
                  '• اعلان‌ها فقط از گروهی می‌آد که در همین صفحه انتخاب کردی.\n'
                  '• پشتیبان‌گیری و بازگردانی: توی «ویرایش برنامه»، منوی بالای صفحه.\n'
                  '• کاملاً آفلاین — هیچ اینترنتی، هیچ جمع‌آوری داده‌ای.',
                ),
                isThreeLine: false,
              ),
              const Divider(height: 1, indent: 56),
              const ListTile(
                leading: Icon(Icons.person_outline_rounded, color: AppColors.saffron),
                title: Text('سازنده و توسعه‌دهنده', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('علیرضا عودی\nAlirezaoudi@cfu.ac.ir'),
              ),
              const Divider(height: 1, indent: 56),
              // شمارهٔ نسخهٔ نصب‌شده — برای اینکه بشه مطمئن شد آخرین بیلد نصبه
              ListTile(
                leading: const Icon(Icons.tag_rounded, color: AppColors.muted),
                title: const Text('نسخهٔ نصب‌شده', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(versionLabel,
                    textDirection: TextDirection.ltr, textAlign: TextAlign.left),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ردیف تنظیمات اعلان یک درس: خاموش/روشن + دقیقهٔ اختصاصی + جلسه‌ها.
class _CourseAlarmTile extends StatelessWidget {
  final Course course;
  final String groupId;
  final VoidCallback onChanged;
  const _CourseAlarmTile({required this.course, required this.groupId, required this.onChanged});

  Future<void> _setMinutes(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('آلارم «${course.shortName}»',
                    style: const TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
              ),
            ),
            RadioListTile<int?>(
              value: null,
              groupValue: course.alarmMinutes,
              activeColor: AppColors.saffron,
              title: const Text('مثل بقیهٔ درس‌ها', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'الان ${fa(SettingsService.instance.settings.minutesBefore)} دقیقه',
                style: const TextStyle(fontSize: 12.5),
              ),
              onChanged: (_) => Navigator.pop(ctx, -1),
            ),
            for (final v in const [0, 5, 10, 15, 20, 30, 45, 60])
              RadioListTile<int?>(
                value: v,
                groupValue: course.alarmMinutes,
                activeColor: AppColors.saffron,
                title: Text(v == 0 ? 'سرِ وقت دقیق' : '${fa(v)} دقیقه قبل',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onChanged: (_) => Navigator.pop(ctx, v),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ScheduleStore.instance.updateCourse(
      course.copyWith(
        alarmMinutes: picked,
        clearAlarmMinutes: picked == -1,
      ),
      groupId: groupId,
    );
    await NotificationService.instance.reschedule();
    onChanged();
  }

  Future<void> _toggleSession(int index) async {
    // بر اساس ایندکس کار می‌کنیم تا با جلسه‌های هم‌مقدار اشتباه نشود.
    final list = List<Session>.of(course.sessions);
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(alarmOff: !list[index].alarmOff);
    await ScheduleStore.instance.updateCourse(course.copyWith(sessions: list), groupId: groupId);
    await NotificationService.instance.reschedule();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final mins = NotificationService.minutesFor(course);
    final on = NotificationService.courseEnabled(course);
    final offSessions = course.sessions.where((s) => s.alarmOff).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: on,
          onChanged: (v) async {
            await ScheduleStore.instance.updateCourse(course.copyWith(muted: !v), groupId: groupId);
            await NotificationService.instance.reschedule();
            onChanged();
          },
          secondary: CircleAvatar(
            radius: 8,
            backgroundColor: course.color,
          ),
          title: Text(course.shortName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(
            !on
                ? 'اعلان این درس خاموش است'
                : '${mins == 0 ? 'سرِ وقت' : '${fa(mins)} دقیقه قبل'}'
                    '${offSessions > 0 ? ' · ${fa(offSessions)} جلسه بی‌اعلان' : ''}',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
        if (on && course.sessions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < course.sessions.length; i++)
                  FilterChip(
                    label: Text(
                      '${kDayNames[course.sessions[i].day]} ${fmtTime(course.sessions[i].start)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    selected: !course.sessions[i].alarmOff,
                    onSelected: (_) => _toggleSession(i),
                    selectedColor: AppColors.saffron.withAlpha(40),
                    checkmarkColor: AppColors.saffron,
                  ),
              ],
            ),
          ),
        if (on)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _setMinutes(context),
                icon: const Icon(Icons.alarm_rounded, size: 18, color: AppColors.saffron),
                label: Text(
                  course.alarmMinutes == null
                      ? 'زمان آلارم: مثل بقیه'
                      : (course.alarmMinutes == 0 ? 'زمان آلارم: سرِ وقت' : 'زمان آلارم: ${fa(course.alarmMinutes!)} دقیقه قبل'),
                  style: const TextStyle(color: AppColors.saffron, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Text(text, style: const TextStyle(fontFamily: kTitleFont, fontSize: 26, color: AppColors.olive)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
