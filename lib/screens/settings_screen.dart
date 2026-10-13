import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../utils.dart';

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

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkExact();
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
      _checkExact().then((_) => _notif.reschedule());
    }
  }

  Future<void> _checkExact() async {
    final ok = await _notif.canScheduleExact();
    if (mounted) setState(() => _exactOk = ok);
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

  @override
  Widget build(BuildContext context) {
    final s = _svc.settings;
    final m = _minutes.round();
    final next = ScheduleStore.instance.findNext(DateTime.now());

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
                              child: Text('${fa(m)} دقیقه',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        Slider(
                          value: _minutes,
                          min: SettingsService.minMinutes.toDouble(),
                          max: SettingsService.maxMinutes.toDouble(),
                          divisions: SettingsService.maxMinutes - SettingsService.minMinutes,
                          label: '${fa(m)} دقیقه',
                          activeColor: AppColors.saffron,
                          onChanged: (v) => setState(() => _minutes = v),
                          onChangeEnd: (v) => _save(s.copyWith(minutesBefore: v.round())),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final q in const [5, 10, 15])
                              ChoiceChip(
                                label: Text('${fa(q)} دقیقه'),
                                selected: m == q,
                                onSelected: (_) {
                                  setState(() => _minutes = q.toDouble());
                                  _save(s.copyWith(minutesBefore: q));
                                },
                              ),
                          ],
                        ),
                        if (next != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'مثلاً برای «${next.ref.course.shortName}» ساعت '
                            '${fmtTime(next.ref.session.start - m / 60)} خبرت می‌کنم.',
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
                subtitle: const Text('شب قبل از هر امتحان، ساعت ۲۰:۰۰'),
              ),
            ],
          ),
          if (_isAndroid && !_exactOk) ...[
            const SizedBox(height: 12),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.alarm_on_rounded, color: AppColors.saffron),
                  title: const Text('دقیق سر وقت بیاد', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('برای اینکه اعلان دقیقاً همون دقیقه بیاد، اجازهٔ «آلارم و یادآوری» رو بده.'),
                  trailing: FilledButton(
                    onPressed: () => _notif.requestExactAlarms(),
                    child: const Text('اجازه'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.send_rounded, color: AppColors.saffron),
                title: const Text('ارسال اعلان آزمایشی', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('ببین اعلان‌ها چه شکلی میان'),
                onTap: () async {
                  await _notif.requestPermission();
                  await _notif.showTest(m);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('درباره'),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('برنامه گروه ۲۴'),
                subtitle: Text(
                  '${fa(ScheduleStore.instance.courses.length)} درس · ${fa(ScheduleStore.instance.totalUnits)} واحد\n'
                  'یادآوری‌ها به وقت تهران و کاملاً آفلاین کار می‌کنن.',
                ),
                isThreeLine: true,
              ),
            ],
          ),
        ],
      ),
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
