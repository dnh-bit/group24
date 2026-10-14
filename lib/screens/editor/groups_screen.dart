import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/schedule_store.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils.dart';

/// مدیریت گروه‌های درسی: افزودن، تغییر نام، انتخاب و حذف.
///
/// هر گروه برنامهٔ مستقل خودش را دارد؛ گروهی که انتخاب شود روی صفحهٔ اصلی،
/// جدول هفتگی، امتحان‌ها و اعلان‌ها اثر می‌گذارد.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _store = ScheduleStore.instance;

  Future<void> _addGroup() async {
    final nameCtrl = TextEditingController();
    var copy = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('گروه درسی جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'نام گروه',
                  hintText: 'مثلاً گروه ۲۵ یا ترم دوم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: copy,
                onChanged: (v) => setLocal(() => copy = v ?? false),
                title: const Text('درس‌های گروه فعلی کپی بشه'),
                subtitle: const Text('به‌جای وارد کردن از صفر', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ساختن')),
          ],
        ),
      ),
    );

    final name = nameCtrl.text;
    nameCtrl.dispose();
    if (ok != true) return;

    await _store.addGroup(name: name, copyCoursesFromActive: copy);
    await NotificationService.instance.reschedule();
    if (mounted) {
      toast(context, copy ? 'گروه ساخته شد (با کپی درس‌ها) ✦' : 'گروه جدید ساخته شد ✦');
    }
  }

  Future<void> _rename(CourseGroup g) async {
    final ctrl = TextEditingController(text: g.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغییر نام گروه'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام گروه', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ذخیره')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _store.renameGroup(g.id, name);
  }

  Future<void> _delete(CourseGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('«${g.name}» پاک بشه؟'),
        content: Text(
          '${fa(g.courses.length)} درس و همهٔ جلسه‌های این گروه پاک می‌شن. '
          'گروه‌های دیگر دست‌نخورده می‌مونن.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.saffron),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _store.removeGroup(g.id);
    await NotificationService.instance.reschedule();
    if (!mounted) return;
    if (!done) {
      toast(context, 'آخرین گروه پاک نمی‌شه');
    } else {
      toast(context, 'گروه پاک شد');
    }
  }

  Future<void> _select(CourseGroup g) async {
    if (g.id == _store.activeGroupId) return;
    await _store.selectGroup(g.id);
    await NotificationService.instance.reschedule();
    if (mounted) toast(context, 'گروه فعال: ${g.name} ✦');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final groups = _store.groups;
        final activeId = _store.activeGroupId;
        return Scaffold(
          appBar: AppBar(
            title: const Text('گروه‌های درسی', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.saffron,
            foregroundColor: Colors.white,
            onPressed: _addGroup,
            icon: const Icon(Icons.add_rounded),
            label: const Text('گروه جدید'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'هر گروه برنامهٔ خودش رو داره. گروهی که «فعال» باشه توی صفحهٔ اصلی، '
                  'جدول هفتگی، امتحان‌ها و اعلان‌ها نشون داده می‌شه.',
                  style: TextStyle(color: AppColors.muted, height: 1.7, fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),
              for (final g in groups)
                _GroupTile(
                  group: g,
                  active: g.id == activeId,
                  canDelete: groups.length > 1,
                  onSelect: () => _select(g),
                  onRename: () => _rename(g),
                  onDelete: () => _delete(g),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final CourseGroup group;
  final bool active;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.active,
    required this.canDelete,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 8, color: active ? AppColors.saffron : AppColors.muted.withAlpha(60)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                            if (active)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.saffron,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'فعال',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fa(group.courses.length)} درس · ${fa(group.totalUnits)} واحد · '
                          '${fa(group.sessionCount)} جلسه',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') onRename();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                    if (canDelete)
                      const PopupMenuItem(value: 'delete', child: Text('حذف گروه')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
