import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/schedule_store.dart';
import '../../jalali.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'session_sheet.dart';
import 'widgets.dart';

class CourseFormScreen extends StatefulWidget {
  final Course? course; // null = درس جدید
  const CourseFormScreen({super.key, this.course});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _store = ScheduleStore.instance;
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _short = TextEditingController(text: widget.course?.short ?? '');
  late final _tiny = TextEditingController(text: widget.course?.tiny ?? '');
  late final _prof = TextEditingController(text: widget.course?.prof ?? '');
  late final _note = TextEditingController(text: widget.course?.note ?? '');
  late String _kind = widget.course?.kind ?? 'تخصصی';
  late int _units = widget.course?.units ?? 2;
  late int _color = widget.course?.colorValue ?? kCoursePalette.first;
  late bool _muted = widget.course?.muted ?? false;
  late List<Session> _sessions = List.of(widget.course?.sessions ?? []);
  late bool _hasExam = widget.course?.exam != null;
  late JDate _examDate = widget.course?.exam?.date ?? _defaultExamDate();
  late double _examStart = widget.course?.exam?.start ?? 8;
  late double _examEnd = widget.course?.exam?.end ?? 10;
  late final _examPlace = TextEditingController(text: widget.course?.exam?.place ?? '');
  bool _dirty = false;

  bool get _isNew => widget.course == null;

  static JDate _defaultExamDate() {
    final now = JDate.fromDateTime(DateTime.now());
    return JDate(now.y, now.m, now.d);
  }

  @override
  void dispose() {
    for (final c in [_name, _short, _tiny, _prof, _note, _examPlace]) {
      c.dispose();
    }
    super.dispose();
  }

  void _mark() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغییرات ذخیره نشه؟'),
        content: const Text('تغییراتی که دادی هنوز ذخیره نشدن.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ادامه بده')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('بیخیال')),
        ],
      ),
    );
    return ok ?? false;
  }

  Course _build() {
    final id = widget.course?.id ?? _store.nextId();
    final short = _short.text.trim();
    return Course(
      id: id,
      name: _name.text.trim(),
      short: short.isEmpty ? _name.text.trim() : short,
      tiny: _tiny.text.trim().isEmpty ? null : _tiny.text.trim(),
      prof: _prof.text.trim(),
      kind: _kind,
      units: _units,
      colorValue: _color,
      exam: _hasExam
          ? Exam(date: _examDate, start: _examStart, end: _examEnd, place: _examPlace.text.trim())
          : null,
      sessions: _sessions,
      note: _note.text.trim(),
      muted: _muted,
    );
  }

  String? _validateExam() {
    if (!_hasExam) return null;
    if (_examEnd <= _examStart) return 'ساعت پایان امتحان باید بعد از شروعش باشه';
    final other = _store.examsSameDay(_build());
    if (other.isNotEmpty) {
      return 'امتحان «${other.first.shortName}» هم همون روزه';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sessions.isEmpty && !_hasExam) {
      final ok = await _askOk('این درس نه جلسه داره نه امتحان. ذخیره کنم؟');
      if (!ok) return;
    }
    final examErr = _validateExam();
    if (examErr != null) {
      toast(context, examErr);
      return;
    }
    final course = _build();
    await _store.upsert(course);
    await NotificationService.instance.reschedule();
    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop(true);
  }

  Future<bool> _askOk(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('آره')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete() async {
    final c = widget.course!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف «${c.shortName}»؟'),
        content: const Text('این درس و همهٔ جلسه‌ها و امتحانش پاک می‌شن. برگشتش فقط با بازگردانی نسخهٔ پشتیبان ممکنه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.remove(c.id);
    await NotificationService.instance.reschedule();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editSession({int? index}) async {
    final s = await showSessionSheet(
      context,
      initial: index == null ? null : _sessions[index],
      courseId: widget.course?.id,
    );
    if (s == null) return;
    setState(() {
      if (index == null) {
        _sessions.add(s);
      } else {
        _sessions[index] = s;
      }
      _dirty = true;
    });
  }

  Future<void> _pickExamDate() async {
    final picked = await showModalBottomSheet<JDate>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (_) => _JalaliPicker(initial: _examDate),
    );
    if (picked != null) {
      setState(() {
        _examDate = picked;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = <String>{};
    for (final s in _sessions) {
      for (final c in _store.conflictsWith(s, exceptCourseId: widget.course?.id)) {
        conflicts.add(c.shortName);
      }
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'درس جدید' : 'ویرایش درس',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            TextButton(onPressed: _save, child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: _mark,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              const SectionHeader('مشخصات'),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'نام کامل درس *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'نام درس لازمه' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _short,
                      decoration: const InputDecoration(labelText: 'نام کوتاه', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _tiny,
                      decoration: const InputDecoration(labelText: 'برای بلوک کوچک', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _prof,
                decoration: const InputDecoration(labelText: 'استاد', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'نوع', border: OutlineInputBorder()),
                      items: [
                        for (final k in {...kCourseKinds, _kind}) DropdownMenuItem(value: k, child: Text(k)),
                      ],
                      onChanged: (v) => setState(() {
                        _kind = v ?? _kind;
                        _dirty = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _UnitsStepper(
                    value: _units,
                    onChanged: (v) => setState(() {
                      _units = v;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              const SectionHeader('رنگ'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in kCoursePalette)
                    GestureDetector(
                      onTap: () => setState(() {
                        _color = c;
                        _dirty = true;
                      }),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _color == c ? AppColors.ink : Colors.white, width: _color == c ? 3 : 2),
                        ),
                        child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ],
              ),
              SectionHeader(
                'جلسه‌ها',
                trailing: TextButton.icon(
                  onPressed: () => _editSession(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن'),
                ),
              ),
              if (_sessions.isEmpty)
                const Card2(child: Text('هنوز جلسه‌ای نداره (مثلاً برای امتحان‌های تنهایی)', style: TextStyle(color: AppColors.muted)))
              else
                for (var i = 0; i < _sessions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card2(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editSession(index: i),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${kDayNames[_sessions[i].day]} · ${fmtTime(_sessions[i].start)} تا ${fmtTime(_sessions[i].end)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(
                                      [if (_sessions[i].room.isNotEmpty) _sessions[i].room, _sessions[i].type].join(' · '),
                                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف جلسه',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => setState(() {
                              _sessions.removeAt(i);
                              _dirty = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (conflicts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ تداخل با: ${conflicts.join('، ')}',
                      style: const TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700)),
                ),
              SectionHeader(
                'امتحان',
                trailing: Switch(
                  value: _hasExam,
                  onChanged: (v) => setState(() {
                    _hasExam = v;
                    _dirty = true;
                  }),
                ),
              ),
              if (_hasExam) ...[
                Card2(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickExamDate,
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, color: AppColors.olive),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${kDayNames[_examDate.weekdayIndex]} ${fa(_examDate.d)} ${kJalaliMonths[_examDate.m - 1]} ${fa(_examDate.y)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        const Text('تغییر', style: TextStyle(color: AppColors.saffron, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TimeField(label: 'شروع امتحان', value: _examStart, onChanged: (v) => setState(() {
                          _examStart = v;
                          _dirty = true;
                        })),
                    const SizedBox(width: 10),
                    TimeField(label: 'پایان امتحان', value: _examEnd, onChanged: (v) => setState(() {
                          _examEnd = v;
                          _dirty = true;
                        })),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _examPlace,
                  decoration: const InputDecoration(labelText: 'مکان امتحان', border: OutlineInputBorder()),
                ),
              ],
              const SectionHeader('یادآوری و یادداشت'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: !_muted,
                onChanged: (v) => setState(() {
                  _muted = !v;
                  _dirty = true;
                }),
                title: const Text('یادآوری این درس روشن باشه'),
              ),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'یادداشت (کتاب، لینک، ...)', border: OutlineInputBorder()),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('حذف این درس'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitsStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _UnitsStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(fa(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('واحد', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          IconButton(
            onPressed: value < 10 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// انتخاب تاریخ شمسی با سه تا لیست: سال، ماه، روز
class _JalaliPicker extends StatefulWidget {
  final JDate initial;
  const _JalaliPicker({required this.initial});

  @override
  State<_JalaliPicker> createState() => _JalaliPickerState();
}

class _JalaliPickerState extends State<_JalaliPicker> {
  late int _y = widget.initial.y;
  late int _m = widget.initial.m;
  late int _d = widget.initial.d;

  @override
  Widget build(BuildContext context) {
    final maxDay = jalaliMonthLength(_y, _m);
    if (_d > maxDay) _d = maxDay;
    final years = [for (var y = _y - 2; y <= _y + 3; y++) y];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تاریخ امتحان', style: TextStyle(fontFamily: kTitleFont, fontSize: 28, color: AppColors.saffron)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _d,
                    decoration: const InputDecoration(labelText: 'روز', border: OutlineInputBorder()),
                    items: [for (var d = 1; d <= maxDay; d++) DropdownMenuItem(value: d, child: Text(fa(d)))],
                    onChanged: (v) => setState(() => _d = v ?? _d),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _m,
                    decoration: const InputDecoration(labelText: 'ماه', border: OutlineInputBorder()),
                    items: [
                      for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(kJalaliMonths[m - 1])),
                    ],
                    onChanged: (v) => setState(() => _m = v ?? _m),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _y,
                    decoration: const InputDecoration(labelText: 'سال', border: OutlineInputBorder()),
                    items: [for (final y in years) DropdownMenuItem(value: y, child: Text(fa(y)))],
                    onChanged: (v) => setState(() => _y = v ?? _y),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, JDate(_y, _m, _d)),
              child: const Padding(padding: EdgeInsets.all(8), child: Text('انتخاب')),
            ),
          ],
        ),
      ),
    );
  }
}
