import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/schedule_store.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'widgets.dart';

/// فرم یک جلسه (روز، ساعت، مکان، نوع). خروجی: Session یا null
Future<Session?> showSessionSheet(BuildContext context, {Session? initial, int? courseId}) {
  return showModalBottomSheet<Session>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _SessionSheet(initial: initial, courseId: courseId),
  );
}

class _SessionSheet extends StatefulWidget {
  final Session? initial;
  final int? courseId;
  const _SessionSheet({this.initial, this.courseId});

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late int _day = widget.initial?.day ?? 0;
  late double _start = widget.initial?.start ?? 8;
  late double _end = widget.initial?.end ?? 10;
  late final _room = TextEditingController(text: widget.initial?.room ?? '');
  late String _type = widget.initial?.type ?? 'نظری';

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Session get _session => Session(day: _day, start: _start, end: _end, room: _room.text.trim(), type: _type);

  @override
  Widget build(BuildContext context) {
    final store = ScheduleStore.instance;
    final valid = _end > _start;
    final clashes = valid ? store.conflictsWith(_session, exceptCourseId: widget.courseId) : const [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.initial == null ? 'افزودن جلسه' : 'ویرایش جلسه',
                  style: const TextStyle(fontFamily: kTitleFont, fontSize: 28, color: AppColors.saffron)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _day,
                decoration: const InputDecoration(labelText: 'روز', border: OutlineInputBorder()),
                items: [
                  for (var d = 0; d < kDayNames.length; d++) DropdownMenuItem(value: d, child: Text(kDayNames[d])),
                ],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TimeField(label: 'شروع', value: _start, onChanged: (v) => setState(() => _start = v)),
                  const SizedBox(width: 10),
                  TimeField(label: 'پایان', value: _end, onChanged: (v) => setState(() => _end = v)),
                ],
              ),
              if (!valid)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('ساعت پایان باید بعد از شروع باشه', style: TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _room,
                decoration: const InputDecoration(labelText: 'مکان / کلاس', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [for (final t in kSessionTypes) ButtonSegment(value: t, label: Text(t))],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              if (clashes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card2(
                  child: Text(
                    '⚠ با «${clashes.map((c) => c.shortName).join('» و «')}» تداخل داره.',
                    style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(context, _session) : null,
                child: const Padding(padding: EdgeInsets.all(8), child: Text('ثبت جلسه')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
