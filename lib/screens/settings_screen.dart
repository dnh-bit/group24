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

/// صفحهٔ تنظیمات — سه بخش روشن:
///   ۱. اعلان‌ها (کلاس + امتحان + دسترسی‌ها)
///   ۲. اعلان هر درس (کشویی، داخلش آلارم / فقط اعلان / خاموش)
///   ۳. آلارم و برنامه و درباره
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
      if (!granted) _toast('اجازهٔ اعلان داده نشد. از تنظیمات گوشی فعالش کن.');
    }
    await _save(_svc.settings.copyWith(classReminders: v));
  }

  Future<void> _toggleExam(bool v) async {
    if (v) await _notif.requestPermission();
    await _save(_svc.settings.copyWith(examReminders: v));
  }

  Future<void> _toggleCancelOneHour(bool v) async {
    await _save(_svc.settings.copyWith(cancelOneHourClasses: v));
    _toast(v ? 'کلاس‌های تک‌ساعته لغو شدند' : 'کلاس‌های تک‌ساعته برگزار می‌شوند');
  }

  /// انتخاب نوع صدا
  Future<void> _pickSound(AppSettings s) async {
    final picked = await _pickFromSheet<AlarmSound>(
      title: 'صدای آلارم',
      current: s.alarmSound,
      values: AlarmSound.values,
      label: (v) => v.label,
      hint: (v) => v.hint,
    );
    if (picked == null || picked == s.alarmSound) return;
    await _save(s.copyWith(alarmSound: picked));
    _toast('صدای آلارم: ${picked.label}');
  }

  /// انتخاب دقیقهٔ آلارم امتحان
  Future<void> _pickExamMinutes(AppSettings s) async {
    final picked = await _pickFromSheet<int>(
      title: 'چند دقیقه قبل از امتحان؟',
      current: s.examAlarmMinutes,
      values: const [0, 15, 30, 45, 60, 90, 120],
      label: (v) => v == 0 ? 'سرِ وقت دقیق' : '${fa(v)} دقیقه قبل',
    );
    if (picked == null) return;
    await _save(s.copyWith(examAlarmMinutes: picked));
  }

  /// یک شیت انتخاب عمومی — همهٔ انتخاب‌ها یک ظاهر و یک رفتار دارند.
  Future<T?> _pickFromSheet<T>({
    required String title,
    required T current,
    required List<T> values,
    required String Function(T) label,
    String Function(T)? hint,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(title,
                      style: const TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
                ),
              ),
              for (final v in values)
                RadioListTile<T>(
                  value: v,
                  groupValue: current,
                  activeColor: AppColors.saffron,
                  title: Text(label(v), style: _tTile),
                  subtitle: hint == null
                      ? null
                      : Text(hint(v), style: const TextStyle(fontSize: 12.5)),
                  onChanged: (x) => Navigator.pop(ctx, x),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// انتخاب گروهی که اعلان‌ها از آن می‌آید
  Future<void> _pickNotifGroup(AppSettings s, ScheduleStore store) async {
    final current = s.notifGroupId.isEmpty ? store.activeGroupId : s.notifGroupId;
    final ids = [for (final g in store.groups) g.id];
    final picked = await _pickFromSheet<String>(
      title: 'اعلان از کدام گروه؟',
      current: ids.contains(current) ? current : (ids.isEmpty ? '' : ids.first),
      values: ids,
      label: (id) => store.groups.firstWhere((g) => g.id == id).name,
      hint: (id) {
        final g = store.groups.firstWhere((x) => x.id == id);
        return '${fa(g.courses.length)} درس · ${fa(g.totalUnits)} واحد';
      },
    );
    if (picked == null) return;
    await _save(s.copyWith(notifGroupId: picked));
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
          // ═══════════ ۱. اعلان‌ها ═══════════
          const _SectionTitle('اعلان‌ها'),

          _Card(children: [
            SwitchListTile(
              value: s.classReminders,
              onChanged: _toggleClass,
              secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.saffron),
              title: const Text('یادآوری کلاس‌ها', style: _tTile),
              subtitle: const Text('قبل از شروع هر کلاس خبرت می‌کنم'),
            ),
            if (s.classReminders) ...[
              const Divider(height: 1, indent: 56),
              _SliderBlock(
                minutes: _minutes,
                label: m == 0 ? 'سرِ وقت' : '${fa(m)} دقیقه',
                onChanged: (v) => setState(() => _minutes = v),
                onDone: (v) => _save(s.copyWith(minutesBefore: v.round())),
                selected: s.minutesBefore,
                onPreset: (q) {
                  setState(() => _minutes = q.toDouble());
                  _save(s.copyWith(minutesBefore: q));
                },
                preview: notifNext == null
                    ? null
                    : 'مثلاً برای «${notifNext.ref.course.shortName}» ساعت '
                        '${fmtTime(notifNext.ref.session.start - m / 60)} خبرت می‌کنم.',
              ),
            ],
          ]),

          const SizedBox(height: 10),

          _Card(children: [
            SwitchListTile(
              value: s.examReminders,
              onChanged: _toggleExam,
              secondary: const Icon(Icons.event_note_rounded, color: AppColors.olive),
              title: const Text('یادآوری امتحان‌ها', style: _tTile),
              subtitle: const Text('شب قبل ساعت ۲۰:۰۰ + یادآوری قبل از شروع'),
            ),
            if (s.examReminders) ...[
              const Divider(height: 1, indent: 56),
              _LinkTile(
                icon: Icons.alarm_rounded,
                color: AppColors.olive,
                title: 'چند دقیقه قبل از امتحان؟',
                value: s.examAlarmMinutes == 0 ? 'سرِ وقت' : '${fa(s.examAlarmMinutes)} دقیقه قبل',
                onTap: () => _pickExamMinutes(s),
              ),
              SwitchListTile(
                value: s.examFullAlarm,
                onChanged: (v) => _save(s.copyWith(examFullAlarm: v)),
                secondary: const Icon(Icons.notifications_paused_rounded, color: AppColors.olive),
                title: const Text('آلارم تمام‌صفحه برای امتحان', style: _tTile),
                subtitle: const Text('اگر خاموش باشد فقط یک اعلان ساده می‌آید'),
              ),
            ],
          ]),

          // دسترسی‌ها فقط وقتی واقعاً لازم است نمایش داده می‌شوند
          if (_isAndroid && (!_exactOk || !_fullScreenOk)) ...[
            const SizedBox(height: 10),
            _Card(children: [
              if (!_exactOk)
                _ActionTile(
                  icon: Icons.alarm_on_rounded,
                  title: 'اجازهٔ آلارم دقیق',
                  subtitle: 'تا آلارم دقیقاً سرِ همان دقیقه بیاید',
                  onTap: () => _notif.requestExactAlarms(),
                ),
              if (!_exactOk && !_fullScreenOk) const Divider(height: 1, indent: 56),
              if (!_fullScreenOk)
                _ActionTile(
                  icon: Icons.fullscreen_rounded,
                  title: 'اجازهٔ نمایش تمام‌صفحه',
                  subtitle: 'اندروید ۱۴+ برای آلارم روی صفحهٔ قفل این را می‌خواهد',
                  onTap: _askFullScreen,
                ),
            ]),
          ],

          // ═══════════ ۲. اعلان هر درس ═══════════
          const SizedBox(height: 24),
          const _SectionTitle('اعلان هر درس'),

          _Card(children: [
            // کل این بخش یک کشویی است: بسته = فقط عنوان و خلاصه،
            // باز = فهرست کامل درس‌ها برای انتخاب اعلان.
            _CourseListExpansion(
              group: notifGroup,
              onChanged: () => setState(() {}),
            ),
          ]),

          // ═══════════ ۳. آلارم ═══════════
          const SizedBox(height: 24),
          const _SectionTitle('آلارم'),

          _Card(children: [
            SwitchListTile(
              value: s.fullScreenAlarm,
              onChanged: (v) => _save(s.copyWith(fullScreenAlarm: v)),
              secondary: const Icon(Icons.phonelink_ring_rounded, color: AppColors.saffron),
              title: const Text('آلارم تمام‌صفحه', style: _tTile),
              subtitle: const Text('روی صفحهٔ قفل هم می‌آید و زنگ می‌زند'),
            ),
            const Divider(height: 1, indent: 56),
            _LinkTile(
              icon: Icons.music_note_rounded,
              title: 'صدای آلارم',
              value: s.alarmSound.label,
              onTap: () => _pickSound(s),
            ),
            SwitchListTile(
              value: s.vibrate,
              onChanged: (v) => _save(s.copyWith(vibrate: v)),
              secondary: const Icon(Icons.vibration_rounded, color: AppColors.saffron),
              title: const Text('لرزش همراه آلارم', style: _tTile),
              subtitle: const Text('گوشی هم می‌لرزد تا متوجه بشی'),
            ),
            const Divider(height: 1, indent: 56),
            _LinkTile(
              icon: Icons.send_rounded,
              title: 'آلارم آزمایشی',
              value: 'همین حالا امتحان کن',
              onTap: () async {
                await _notif.requestPermission();
                await _notif.showTest(m);
              },
            ),
          ]),

          // ═══════════ ۴. برنامه و گروه‌ها ═══════════
          const SizedBox(height: 24),
          const _SectionTitle('برنامه'),

          _Card(children: [
            _LinkTile(
              icon: Icons.groups_2_rounded,
              title: 'گروهی که اعلان می‌دهد',
              value: notifGroup.name,
              onTap: () => _pickNotifGroup(s, store),
            ),
            const Divider(height: 1, indent: 56),
            _LinkTile(
              icon: Icons.groups_rounded,
              title: 'مدیریت گروه‌ها',
              value: '${fa(store.groups.length)} گروه',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              ),
            ),
            const Divider(height: 1, indent: 56),
            _LinkTile(
              icon: Icons.auto_awesome_rounded,
              title: 'دستیار هوشمند',
              value: 'پرامپت آماده',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          _Card(children: [
            SwitchListTile(
              value: s.cancelOneHourClasses,
              onChanged: _toggleCancelOneHour,
              secondary: const Icon(Icons.timer_off_outlined, color: AppColors.saffron),
              title: const Text('لغو کلاس‌های تک‌ساعته', style: _tTile),
              subtitle: const Text('کلاس‌های یک‌ساعته برگزار نشوند و اعلان نگیرند (ویژهٔ فرهنگیان)'),
            ),
          ]),

          // ═══════════ ۵. درباره ═══════════
          const SizedBox(height: 24),
          const _SectionTitle('درباره'),

          _Card(children: [
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('دربارهٔ برنامه درسی', style: _tTile),
              subtitle: Text(
                'برنامهٔ هفتگی کلاس‌ها و تاریخ امتحان‌ها با آلارم و یادآوری.\n'
                'کاملاً آفلاین — هیچ اینترنتی، هیچ جمع‌آوری داده‌ای.',
              ),
            ),
            const Divider(height: 1, indent: 56),
            const ListTile(
              leading: Icon(Icons.person_outline_rounded, color: AppColors.saffron),
              title: Text('سازنده و توسعه‌دهنده', style: _tTile),
              subtitle: Text('علیرضا عودی\nAlirezaoudi@cfu.ac.ir'),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.tag_rounded, color: AppColors.muted),
              title: const Text('نسخهٔ نصب‌شده', style: _tTile),
              subtitle: Text(versionLabel,
                  textDirection: TextDirection.ltr, textAlign: TextAlign.left),
            ),
          ]),
        ],
      ),
    );
  }
}

const _tTile = TextStyle(fontWeight: FontWeight.w700);

// ═══════════════════ اجزای کوچک مشترک ═══════════════════

/// ردیفی که مقدار فعلی را نشان می‌دهد و با لمس، شیت انتخاب باز می‌شود.
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.saffron),
      title: Text(title, style: _tTile),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }
}

/// ردیفی با دکمهٔ «اجازه».
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.saffron),
      title: Text(title, style: _tTile),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
      trailing: FilledButton(onPressed: onTap, child: const Text('اجازه')),
    );
  }
}

/// اسلایدر «چند دقیقه قبل» + گزینه‌های آماده + یک مثال زنده.
class _SliderBlock extends StatelessWidget {
  final double minutes;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onDone;
  final ValueChanged<int> onPreset;
  final int selected;
  final String? preview;
  const _SliderBlock({
    required this.minutes,
    required this.label,
    required this.onChanged,
    required this.onDone,
    required this.onPreset,
    required this.selected,
    this.preview,
  });

  static const _presets = [0, 5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('چند دقیقه قبل؟', style: _tTile)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
          Slider(
            value: minutes,
            min: 0,
            max: SettingsService.maxMinutes.toDouble(),
            divisions: SettingsService.maxMinutes,
            label: label,
            activeColor: AppColors.saffron,
            onChanged: onChanged,
            onChangeEnd: onDone,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final q in _presets)
                ChoiceChip(
                  label: Text(q == 0 ? 'سرِ وقت' : '${fa(q)} دقیقه',
                      style: const TextStyle(fontSize: 12.5)),
                  selected: selected == q,
                  onSelected: (_) => onPreset(q),
                ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            Text(preview!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// کشویی فهرست درس‌ها: بسته = عنوان گروه + خلاصهٔ وضعیت؛ باز = همهٔ درس‌ها.
class _CourseListExpansion extends StatefulWidget {
  final CourseGroup group;
  final VoidCallback onChanged;
  const _CourseListExpansion({required this.group, required this.onChanged});

  @override
  State<_CourseListExpansion> createState() => _CourseListExpansionState();
}

class _CourseListExpansionState extends State<_CourseListExpansion> {
  bool _open = false;

  CourseGroup get group => widget.group;

  @override
  Widget build(BuildContext context) {
    final total = group.courses.length;
    final alarms = group.courses
        .where((c) => c.alert == CourseAlert.alarm && !c.muted)
        .length;
    final notices = group.courses
        .where((c) => c.alert == CourseAlert.notice && !c.muted)
        .length;
    final offs = total - alarms - notices;

    // خلاصهٔ کوتاه برای حالت بسته
    final parts = <String>[
      if (alarms > 0) '${fa(alarms)} آلارم',
      if (notices > 0) '${fa(notices)} اعلان',
      if (offs > 0) '${fa(offs)} خاموش',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: () => setState(() => _open = !_open),
          leading: const Icon(Icons.tune_rounded, color: AppColors.saffron),
          title: Text('برنامهٔ «${group.name}»', style: _tTile),
          subtitle: Text(
            total == 0
                ? 'این گروه درسی ندارد'
                : _open
                    ? 'برای هر درس، حالت اعلان را انتخاب کن'
                    : '${fa(total)} درس · ${parts.isEmpty ? 'همه خاموش' : parts.join(' · ')}',
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
          trailing: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.muted),
        ),
        if (_open) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'روی هر درس بزن تا باز شود. هر درس می‌تواند آلارم بزند، '
              'فقط اعلان بگیرد، یا کاملاً خاموش باشد.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6),
            ),
          ),
          const Divider(height: 1),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text('این گروه درسی ندارد.', style: TextStyle(color: AppColors.muted)),
            ),
          for (final c in group.courses)
            _CourseAlarmExpansion(
              key: ValueKey('${group.id}-${c.id}'),
              course: c,
              groupId: group.id,
              onChanged: () {
                setState(() {}); // خلاصهٔ بالای کشویی هم به‌روز شود
                widget.onChanged();
              },
            ),
        ],
      ],
    );
  }
}

/// کشویی یک درس: بسته = نام + خلاصهٔ حالت؛ باز = انتخاب حالت، زمان و جلسه‌ها.
class _CourseAlarmExpansion extends StatefulWidget {
  final Course course;
  final String groupId;
  final VoidCallback onChanged;
  const _CourseAlarmExpansion({
    super.key,
    required this.course,
    required this.groupId,
    required this.onChanged,
  });

  @override
  State<_CourseAlarmExpansion> createState() => _CourseAlarmExpansionState();
}

class _CourseAlarmExpansionState extends State<_CourseAlarmExpansion> {
  bool _open = false;
  bool _busy = false;

  Course get course => widget.course;

  Future<void> _update(Course next) async {
    if (_busy) return;
    _busy = true;
    await ScheduleStore.instance.updateCourse(next, groupId: widget.groupId);
    await NotificationService.instance.reschedule();
    _busy = false;
    widget.onChanged();
  }

  Future<void> _setAlert(CourseAlert v) async {
    await _update(course.copyWith(alert: v, muted: v == CourseAlert.off));
  }

  Future<void> _pickMinutes() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('زمان آلارم «${course.shortName}»',
                      style: const TextStyle(fontFamily: kTitleFont, fontSize: 22, color: AppColors.saffron)),
                ),
              ),
              RadioListTile<int>(
                value: -1,
                groupValue: course.alarmMinutes ?? -1,
                activeColor: AppColors.saffron,
                title: const Text('مثل بقیهٔ درس‌ها', style: _tTile),
                subtitle: Text('الان ${fa(SettingsService.instance.settings.minutesBefore)} دقیقه',
                    style: const TextStyle(fontSize: 12.5)),
                onChanged: (_) => Navigator.pop(ctx, -1),
              ),
              for (final v in const [0, 5, 10, 15, 20, 30, 45, 60])
                RadioListTile<int>(
                  value: v,
                  groupValue: course.alarmMinutes ?? -1,
                  activeColor: AppColors.saffron,
                  title: Text(v == 0 ? 'سرِ وقت دقیق' : '${fa(v)} دقیقه قبل', style: _tTile),
                  onChanged: (_) => Navigator.pop(ctx, v),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _update(course.copyWith(
      alarmMinutes: picked == -1 ? null : picked,
      clearAlarmMinutes: picked == -1,
    ));
  }

  Future<void> _toggleSession(int index) async {
    final list = List<Session>.of(course.sessions);
    if (index < 0 || index >= list.length) return;
    // مقدار مؤثر فعلی را برمی‌گردانیم (پیش‌فرضِ تک‌ساعته هم حساب می‌شود)
    list[index] = list[index].copyWith(alarmOff: list[index].alarmEnabled);
    await _update(course.copyWith(sessions: list));
  }

  /// «همه روشن / همه خاموش»: همهٔ جلسه‌ها را صریح روی یک مقدار می‌گذارد.
  Future<void> _toggleAllSessions(bool on) async {
    final list = [for (final s in course.sessions) s.copyWith(alarmOff: !on)];
    await _update(course.copyWith(sessions: list));
  }

  @override
  Widget build(BuildContext context) {
    final on = course.alertsOn && !course.muted;
    final offSessions = course.sessions.where((s) => !s.alarmEnabled).length;
    final mins = NotificationService.minutesFor(course);

    final (Color tint, IconData icon) = switch (course.alert) {
      CourseAlert.alarm => (AppColors.saffron, Icons.alarm_on_rounded),
      CourseAlert.notice => (AppColors.olive, Icons.notifications_active_outlined),
      CourseAlert.off => (AppColors.muted, Icons.notifications_off_outlined),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── ردیف بسته ──
        ListTile(
          onTap: () => setState(() => _open = !_open),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: course.color.withAlpha(on ? 40 : 18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: on ? tint : AppColors.muted),
          ),
          title: Text(course.shortName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: on ? null : AppColors.muted,
              )),
          subtitle: Text(
            !on
                ? 'خاموش — هیچ اعلانی نمی‌آید'
                : course.alert == CourseAlert.alarm
                    ? 'آلارم · ${mins == 0 ? 'سرِ وقت' : '${fa(mins)} دقیقه قبل'}'
                    : 'فقط اعلان · بدون زنگ',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on && offSessions > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('${fa(offSessions)} بی‌اعلان',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.muted),
            ],
          ),
        ),

        // ── محتوای باز ──
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<CourseAlert>(
                  segments: const [
                    ButtonSegment(
                      value: CourseAlert.alarm,
                      icon: Icon(Icons.alarm_on_rounded, size: 17),
                      label: Text('آلارم', style: TextStyle(fontSize: 12.5)),
                    ),
                    ButtonSegment(
                      value: CourseAlert.notice,
                      icon: Icon(Icons.notifications_outlined, size: 17),
                      label: Text('اعلان', style: TextStyle(fontSize: 12.5)),
                    ),
                    ButtonSegment(
                      value: CourseAlert.off,
                      icon: Icon(Icons.notifications_off_outlined, size: 17),
                      label: Text('خاموش', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                  selected: {course.alert},
                  onSelectionChanged: (v) => _setAlert(v.first),
                ),
                const SizedBox(height: 8),
                Text(
                  course.alert.hint,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
                ),

                if (on) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      const Text('زمان:', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _pickMinutes,
                            child: Text(
                              course.alarmMinutes == null
                                  ? 'مثل بقیه (${fa(SettingsService.instance.settings.minutesBefore)} دقیقه)'
                                  : (course.alarmMinutes == 0
                                      ? 'سرِ وقت'
                                      : '${fa(course.alarmMinutes!)} دقیقه قبل'),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.saffron),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (course.sessions.length > 1) ...[
                    const Divider(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('کدام جلسه اعلان بگیرد؟',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                          onPressed: () => _toggleAllSessions(offSessions > 0),
                          child: Text(
                            offSessions > 0 ? 'همه روشن' : 'همه خاموش',
                            style: const TextStyle(fontSize: 12, color: AppColors.saffron),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < course.sessions.length; i++)
                          FilterChip(
                            label: Text(
                              '${kDayNames[course.sessions[i].day]} ${fmtTime(course.sessions[i].start)}'
                              '${course.sessions[i].isOneHour ? ' · ۱ ساعته' : ''}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            selected: course.sessions[i].alarmEnabled,
                            onSelected: (_) => _toggleSession(i),
                            selectedColor: AppColors.saffron.withAlpha(40),
                            checkmarkColor: AppColors.saffron,
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        const Divider(height: 1, indent: 56),
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
