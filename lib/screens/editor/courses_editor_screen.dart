import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/schedule_store.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'course_form_screen.dart';
import 'widgets.dart';

class CoursesEditorScreen extends StatefulWidget {
  const CoursesEditorScreen({super.key});

  @override
  State<CoursesEditorScreen> createState() => _CoursesEditorScreenState();
}

class _CoursesEditorScreenState extends State<CoursesEditorScreen> {
  final _store = ScheduleStore.instance;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Course? c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseFormScreen(course: c)),
    );
  }

  Future<void> _toggleMuted(Course c, bool on) async {
    await _store.setMuted(c.id, !on);
    await NotificationService.instance.reschedule();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _store.exportJson(pretty: true)));
    if (mounted) toast(context, 'پشتیبان همهٔ گروه‌ها کپی شد ✦');
  }

  Future<void> _copyActiveGroup() async {
    await Clipboard.setData(ClipboardData(text: _store.exportActiveGroupJson(pretty: true)));
    if (mounted) toast(context, 'پشتیبان «${_store.activeGroup.name}» کپی شد ✦');
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازگردانی از نسخهٔ پشتیبان'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'متن JSON رو اینجا بچسبون. برنامهٔ فعلی جایگزین می‌شه.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          Builder(
            builder: (c2) => FilledButton(
              onPressed: () => Navigator.pop(c2, ctrl.text),
              child: const Text('بازگردانی'),
            ),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.trim().isEmpty) return;
    try {
      final n = await _store.importJson(text);
      await NotificationService.instance.reschedule();
      if (mounted) toast(context, '${fa(n)} درس بازگردانی شد ✦');
    } catch (_) {
      if (mounted) toast(context, 'متن وارد شده معتبر نیست');
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('همهٔ گروه‌ها برگردونده بشن؟'),
        content: const Text(
          'همهٔ گروه‌های درسی و تغییراتشون پاک می‌شن و فقط «گروه اصلی» با '
          'برنامهٔ پیش‌فرض می‌مونه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('آره')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.resetAllGroups();
    await NotificationService.instance.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final all = _store.courses;
    final list = all.where((c) {
      if (_q.trim().isEmpty) return true;
      final q = _q.trim();
      return c.name.contains(q) || c.shortName.contains(q) || c.prof.contains(q);
    }).toList();
    final conflicts = _store.conflicts();
    final examCount = all.where((c) => c.exam != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش برنامه', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'copy':
                  _copy();
                case 'copyGroup':
                  _copyActiveGroup();
                case 'import':
                  _import();
                case 'reset':
                  _reset();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('کپی پشتیبان همهٔ گروه‌ها')),
              PopupMenuItem(value: 'copyGroup', child: Text('کپی پشتیبان گروه فعال')),
              PopupMenuItem(value: 'import', child: Text('بازگردانی از متن')),
              PopupMenuItem(value: 'reset', child: Text('بازگردانی همهٔ گروه‌ها')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.saffron,
        foregroundColor: Colors.white,
        onPressed: () => _open(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('درس جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              _Stat(label: 'درس', value: fa(all.length)),
              const SizedBox(width: 8),
              _Stat(label: 'واحد', value: fa(_store.totalUnits)),
              const SizedBox(width: 8),
              _Stat(label: 'امتحان', value: fa(examCount)),
              const SizedBox(width: 8),
              _Stat(label: 'ساعت/هفته', value: fa(_store.weeklyHours.toStringAsFixed(1))),
            ],
          ),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card2(
              child: Text(
                '⚠ ${fa(conflicts.length)} تداخل تو برنامه هست:\n'
                '${conflicts.map((c) => '${c.a.course.shortName} ↔ ${c.b.course.shortName} (${kDayNames[c.a.session.day]})').join('\n')}',
                style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700, height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'جستجوی درس یا استاد',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('چیزی پیدا نشد', style: TextStyle(color: AppColors.muted))),
            ),
          for (final c in list) _CourseTile(course: c, onTap: () => _open(c), onMuted: (on) => _toggleMuted(c, on)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.olive)),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final ValueChanged<bool> onMuted;
  const _CourseTile({required this.course, required this.onTap, required this.onMuted});

  @override
  Widget build(BuildContext context) {
    final c = course;
    final sessionsText = c.sessions.isEmpty
        ? 'بدون جلسه'
        : c.sessions.map((s) => '${kDayNames[s.day]} ${fmtTime(s.start)}').join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 8, color: c.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          [if (c.prof.isNotEmpty) c.prof, '${fa(c.units)} واحد'].join(' · '),
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(sessionsText, style: const TextStyle(fontSize: 12.5)),
                        if (c.exam != null)
                          Text(
                            'امتحان: ${c.exam!.weekdayName} ${c.exam!.jalaliText}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.olive, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: c.muted ? 'یادآوری خاموشه' : 'یادآوری روشنه',
                    icon: Icon(
                      c.muted ? Icons.notifications_off_outlined : Icons.notifications_active_rounded,
                      color: c.muted ? AppColors.muted : AppColors.saffron,
                    ),
                    onPressed: () => onMuted(c.muted),
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
