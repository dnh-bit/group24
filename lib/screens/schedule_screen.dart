import 'dart:async';

import 'package:flutter/material.dart';

import '../data/default_schedule.dart';
import '../data/models.dart';
import '../data/schedule_store.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/star.dart';
import 'editor/course_form_screen.dart';
import 'editor/courses_editor_screen.dart';
import 'editor/groups_screen.dart';

enum _ViewMode { day, week }

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _store = ScheduleStore.instance;
  DateTime _now = DateTime.now();
  Timer? _timer;
  late int _selectedDay = dayIndexOf(_now);
  _ViewMode _mode = _ViewMode.day;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openCourse(Course c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CourseSheet(course: c, now: _now),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          const Text('هنوز هیچ کلاسی ثبت نشده', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CourseFormScreen()),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن درس'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final today = dayIndexOf(_now);
    final next = _store.findNext(_now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه درسی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'گروه‌های درسی',
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GroupsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'ویرایش کلاس‌ها و امتحان‌ها',
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoursesEditorScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _Poster(),
          _ActiveGroupBar(groupName: _store.activeGroup.name),
          if (next != null) _NextPill(next: next, onTap: () => _openCourse(next.ref.course)),
          const SizedBox(height: 14),
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(value: _ViewMode.day, label: Text('روزانه'), icon: Icon(Icons.view_agenda_rounded)),
              ButtonSegment(value: _ViewMode.week, label: Text('کل هفته'), icon: Icon(Icons.calendar_view_week_rounded)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
          if (_store.courses.isEmpty)
            _emptyState()
          else if (_mode == _ViewMode.day) ...[
            _DayChips(
              store: _store,
              selected: _selectedDay,
              today: today,
              onSelect: (d) => setState(() => _selectedDay = d),
            ),
            const SizedBox(height: 12),
            _DayList(
              store: _store,
              day: _selectedDay,
              isToday: _selectedDay == today,
              hour: hourOf(_now),
              onTap: _openCourse,
            ),
          ] else
            _WeekGrid(store: _store, today: today, hour: hourOf(_now), onTap: _openCourse),
          const SizedBox(height: 10),
          const Text(
            'روی هر کلاس بزن تا استاد، مکان و تاریخ امتحانش رو ببینی.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 26),
          _ExamsSection(store: _store, now: _now, onTap: _openCourse),
        ],
      ),
    );
  }
}

// ───────────────────────── Poster ─────────────────────────

class _Poster extends StatelessWidget {
  const _Poster();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.saffron, width: 5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kEyebrow, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.olive, fontSize: 12.5)),
                SizedBox(height: 4),
                Text(
                  'برنامهٔ هفتگی',
                  style: TextStyle(fontFamily: kTitleFont, fontSize: 58, height: 1.05, color: AppColors.saffron),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          SpinningStar(size: 70),
        ],
      ),
    );
  }
}

// ───────────────────────── Active group bar ─────────────────────────

class _ActiveGroupBar extends StatelessWidget {
  final String groupName;
  const _ActiveGroupBar({required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded, size: 15, color: AppColors.olive),
          const SizedBox(width: 6),
          Text(
            groupName,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.olive, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Next class pill ─────────────────────────

class _NextPill extends StatelessWidget {
  final NextClass next;
  final VoidCallback onTap;
  const _NextPill({required this.next, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = next.ref.course;
    final s = next.ref.session;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const _Pulse(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next.ongoing ? 'الان سر کلاسی:' : 'کلاس بعدی:',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      Text(c.shortName, style: TextStyle(color: c.color, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        '${next.whenLabel} · ${fmtTime(s.start)} · ${s.room}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
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

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.saffron,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.saffron.withAlpha(((1 - t) * 130).round()),
                spreadRadius: t * 9,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── Day view ─────────────────────────

class _DayChips extends StatelessWidget {
  final ScheduleStore store;
  final int selected;
  final int today;
  final ValueChanged<int> onSelect;
  const _DayChips({required this.store, required this.selected, required this.today, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, d) {
          final isSel = d == selected;
          final isToday = d == today;
          final count = store.sessionsOn(d).length;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSel ? AppColors.saffron : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isToday && !isSel ? AppColors.saffron : Colors.transparent, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    kDayNames[d],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : (d == 6 ? AppColors.muted : AppColors.ink),
                    ),
                  ),
                  Text(
                    isToday ? 'امروز' : (count == 0 ? 'تعطیل' : '${fa(count)} کلاس'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : (isToday ? AppColors.saffron : AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  final ScheduleStore store;
  final int day;
  final bool isToday;
  final double hour;
  final ValueChanged<Course> onTap;
  const _DayList({required this.store, required this.day, required this.isToday, required this.hour, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final list = store.sessionsOn(day);
    if (list.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: const Text(
          'تعطیل · وقت استراحت و تمرین نمایش ✦',
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
      );
    }
    return Column(
      children: [
        for (final ref in list)
          _SessionCard(
            refData: ref,
            ongoing: isToday && ref.session.start <= hour && hour < ref.session.end,
            past: isToday && ref.session.end <= hour,
            onTap: () => onTap(ref.course),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRef refData;
  final bool ongoing;
  final bool past;
  final VoidCallback onTap;
  const _SessionCard({required this.refData, required this.ongoing, required this.past, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = refData.course;
    final s = refData.session;
    return Opacity(
      opacity: past ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Text(fmtTime(s.start), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(fmtTime(s.end), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Material(
                color: c.color,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: ongoing ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: ongoing
                          ? [BoxShadow(color: c.color.withAlpha(120), blurRadius: 18, offset: const Offset(0, 8))]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ongoing)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                            child: Text('در حال برگزاری',
                                style: TextStyle(color: c.color, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.shortName,
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            if (c.muted)
                              const Icon(Icons.notifications_off_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(s.room,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                            ),
                            const SizedBox(width: 8),
                            _Tag(text: s.type, dark: false),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (c.prof.isNotEmpty)
                          Text('استاد ${c.prof}',
                              style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 12.5)),
                      ],
                    ),
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

class _Tag extends StatelessWidget {
  final String text;
  final bool dark;
  const _Tag({required this.text, this.dark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : Colors.white.withAlpha(50),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ───────────────────────── Week grid (مثل نسخهٔ وب) ─────────────────────────

class _WeekGrid extends StatelessWidget {
  final ScheduleStore store;
  final int today;
  final double hour;
  final ValueChanged<Course> onTap;
  const _WeekGrid({required this.store, required this.today, required this.hour, required this.onTap});

  static const double pxPerHour = 64;
  static const double dayColW = 76;
  static const double rowH = 78;

  @override
  Widget build(BuildContext context) {
    final (dayStart, dayEnd) = store.gridRange;
    double x(double h) => (h - dayStart) * pxPerHour;
    final trackW = (dayEnd - dayStart) * pxPerHour;
    final ticks = [for (var t = dayStart; t <= dayEnd - 1 + 0.001; t += 1) t];
    // جمعه فقط وقتی جدا نشون داده می‌شه که کلاسی نداشته باشه
    final fridayFree = store.sessionsOn(6).isEmpty;
    final days = fridayFree ? 6 : 7;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // محور ساعت
              Row(
                children: [
                  const SizedBox(width: dayColW),
                  SizedBox(
                    width: trackW,
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final t in ticks)
                          Positioned(
                            right: x(t) - 22,
                            width: 44,
                            top: 0,
                            child: Text(fmtTime(t),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              for (var d = 0; d < days; d++)
                Container(
                  height: rowH,
                  decoration: BoxDecoration(
                    color: d == today ? const Color(0xFFFFF1E0) : null,
                    borderRadius: BorderRadius.circular(14),
                    border: d == today ? null : const Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: dayColW,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kDayNames[d],
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: d == today ? AppColors.saffron : AppColors.ink,
                                )),
                            if (d == today)
                              const Text('امروز',
                                  style: TextStyle(
                                      color: AppColors.saffron, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: trackW,
                        height: rowH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final t in ticks)
                              Positioned(
                                right: x(t),
                                top: 0,
                                bottom: 0,
                                child: Container(width: 1, color: AppColors.line),
                              ),
                            for (final ref in store.sessionsOn(d))
                              Positioned(
                                right: x(ref.session.start) + 3,
                                width: ref.session.length * pxPerHour - 6,
                                top: 7,
                                bottom: 7,
                                child: _WeekBlock(refData: ref, onTap: () => onTap(ref.course)),
                              ),
                            if (d == today && hour >= dayStart && hour <= dayEnd)
                              Positioned(
                                right: x(hour) - 1.5,
                                top: -3,
                                bottom: -3,
                                child: Container(
                                  width: 3,
                                  decoration: BoxDecoration(
                                    color: AppColors.saffron,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: const [BoxShadow(color: AppColors.saffron, blurRadius: 10)],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // جمعه
              if (fridayFree)
              Container(
                height: 50,
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
                child: Row(
                  children: [
                    const SizedBox(
                      width: dayColW,
                      child: Text('جمعه', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                    ),
                    Container(
                      width: trackW,
                      margin: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line, width: 2),
                      ),
                      child: const Text('تعطیل · وقت استراحت و تمرین نمایش ✦',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekBlock extends StatelessWidget {
  final SessionRef refData;
  final VoidCallback onTap;
  const _WeekBlock({required this.refData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = refData.course;
    final s = refData.session;
    final long = s.length >= 2;
    return Material(
      color: c.color,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                long ? c.shortName : c.tinyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.3),
              ),
              Text(
                long ? [if (s.room.isNotEmpty) s.room, s.type].join(' · ') : fmtTime(s.start),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Exams ─────────────────────────

class _ExamsSection extends StatelessWidget {
  final ScheduleStore store;
  final DateTime now;
  final ValueChanged<Course> onTap;
  const _ExamsSection({required this.store, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final exams = store.examsSorted();
    if (exams.isEmpty) return const SizedBox.shrink();
    final months = {for (final c in exams) c.exam!.monthName}.join(' و ');
    final year = fa(exams.first.exam!.date.y);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('فصل امتحان‌ها',
                style: TextStyle(fontFamily: kTitleFont, fontSize: 36, color: AppColors.olive)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$months $year',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final c in exams) _Ticket(course: c, now: now, onTap: () => onTap(c)),
      ],
    );
  }
}

class _Ticket extends StatelessWidget {
  final Course course;
  final DateTime now;
  final VoidCallback onTap;
  const _Ticket({required this.course, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = course.exam!;
    final left = e.daysLeft(now);
    final leftText = left > 0 ? '${fa(left)} روز مانده' : (left == 0 ? 'امروز!' : 'برگزار شد');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 72,
                  color: course.color,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.dayText,
                          style: const TextStyle(
                              fontFamily: kTitleFont, fontSize: 34, color: Colors.white, height: 1.1)),
                      Text(e.monthName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.shortName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('${e.weekdayName} · ${e.timeText}${e.place.isEmpty ? '' : ' · ${e.place}'}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        Text(leftText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
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

// ───────────────────────── Course details sheet ─────────────────────────

class _CourseSheet extends StatelessWidget {
  final Course course;
  final DateTime now;
  const _CourseSheet({required this.course, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = course;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 12,
                    decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: TextStyle(fontFamily: kTitleFont, fontSize: 26, color: c.color, height: 1.3)),
                        Text([if (c.prof.isNotEmpty) 'استاد ${c.prof}', '${fa(c.units)} واحد', c.kind].join(' · '),
                            style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final s in c.sessions)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(kDayNames[s.day], style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('${fmtTime(s.start)} تا ${fmtTime(s.end)}'),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.room, overflow: TextOverflow.ellipsis)),
                    _Tag(text: s.type),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: c.exam == null
                  ? const Text('بدون امتحان پایانی', style: TextStyle(fontWeight: FontWeight.w700))
                  : Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'امتحان: '),
                        TextSpan(
                            text: '${c.exam!.weekdayName} ${c.exam!.jalaliText}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' · ساعت ${c.exam!.timeText}'),
                        if (c.exam!.place.isNotEmpty) TextSpan(text: ' · ${c.exam!.place}'),
                        if (c.exam!.daysLeft(now) > 0)
                          TextSpan(
                            text: '  (${fa(c.exam!.daysLeft(now))} روز مانده)',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
