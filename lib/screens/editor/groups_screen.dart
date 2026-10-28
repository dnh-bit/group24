import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/backup_code.dart';
import '../../data/schedule_store.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../ai_assistant_screen.dart';
import 'courses_editor_screen.dart';
import 'widgets.dart';

/// مدیریت گروه‌های درسی: انتخاب گروه فعال، افزودن (از صفر / کپی / فایل /
/// متن / دستیار هوشمند)، تغییر نام، ویرایش درس‌ها، پشتیبان و حذف.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _store = ScheduleStore.instance;

  // ───────────── افزودن گروه ─────────────

  Future<void> _addGroupFlow() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // ارتفاع آزاد تا همهٔ گزینه‌ها جا بشن
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            // فاصله برای نوار ناوبری سیستم + کیبورد آینده
            MediaQuery.of(ctx).padding.bottom + 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('گروه جدید از کجا بیاد؟',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'هر گروه یه برنامهٔ مستقله؛ بعد از ساخته شدن، گروه فعال می‌شه.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SheetTile(
                icon: Icons.edit_note_rounded,
                title: 'شروع از صفر',
                subtitle: 'گروه خالی؛ درس‌ها رو خودت توی ویرایشگر اضافه می‌کنی',
                onTap: () => Navigator.pop(ctx, 'empty'),
              ),
              _SheetTile(
                icon: Icons.copy_rounded,
                title: 'کپی درس‌های گروه فعال',
                subtitle: 'همهٔ درس‌های «${_store.activeGroup.name}» کپی می‌شن',
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
              _SheetTile(
                icon: Icons.file_open_outlined,
                title: 'از فایل پشتیبان یا خروجی چت‌بات',
                subtitle: 'انتخاب فایل .json از حافظهٔ گوشی',
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
              _SheetTile(
                icon: Icons.content_paste_rounded,
                title: 'از متن چسبانده‌شده',
                subtitle: 'متن JSON یا کد CP2 رو مستقیم می‌چسبونی',
                onTap: () => Navigator.pop(ctx, 'text'),
              ),
              _SheetTile(
                icon: Icons.auto_awesome_rounded,
                title: 'با دستیار هوشمند',
                subtitle: 'پرامپت آماده بگیر، به چت‌بات بده، خروجی رو بیار',
                onTap: () => Navigator.pop(ctx, 'ai'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'empty':
        await _createNamed((name) async {
          await _store.addGroup(name: name);
          return 'گروه خالی ساخته شد — با «درس جدید» شروع کن ✦';
        });
      case 'copy':
        await _createNamed((name) async {
          await _store.addGroup(name: name, copyCoursesFromActive: true);
          return 'گروه با کپی درس‌ها ساخته شد ✦';
        });
      case 'file':
        await _importFromFile();
      case 'text':
        await _importFromText();
      case 'ai':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
        );
    }
  }

  Future<void> _createNamed(Future<String> Function(String name) create) async {
    final name = await _askName();
    if (name == null || !mounted) return;
    final msg = await create(name);
    await NotificationService.instance.reschedule();
    if (mounted) toast(context, msg);
  }

  Future<String?> _askName() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نام گروه جدید'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'نام گروه',
            hintText: 'مثلاً ترم دوم یا گروه ۲۵',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => ctrl.text.trim().isEmpty ? null : Navigator.pop(ctx, ctrl.text),
            child: const Text('ساختن'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFile() async {
    String? text;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      }
    } catch (_) {
      if (mounted) toast(context, 'خوندن فایل ممکن نشد');
      return;
    }
    if (text == null) return;
    final name = await _askName();
    if (name == null || !mounted) return;
    try {
      final g = await _store.importAsNewGroup(text, name: name);
      await NotificationService.instance.reschedule();
      if (mounted) toast(context, '«${g.name}» با ${fa(g.courses.length)} درس ساخته شد ✦');
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'فایل قابل قبول نبود — فرمت JSON رو چک کن');
    }
  }

  Future<void> _importFromText() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن گروه از متن'),
        content: TextField(
          controller: ctrl,
          maxLines: 9,
          decoration: const InputDecoration(
            hintText: 'متن JSON رو بچسبون — حتی اگر چت‌بات توضیح اضافه نوشته باشه، خودش تمیز می‌شه.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ادامه')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    final name = await _askName();
    if (name == null || !mounted) return;
    try {
      final g = await _store.importAsNewGroup(text, name: name);
      await NotificationService.instance.reschedule();
      if (mounted) toast(context, '«${g.name}» با ${fa(g.courses.length)} درس ساخته شد ✦');
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'متن قابل قبول نبود — فرمت JSON رو چک کن');
    }
  }

  // ───────────── عملیات روی گروه ─────────────

  Future<void> _select(CourseGroup g) async {
    if (g.id == _store.activeGroupId) return;
    await _store.selectGroup(g.id);
    await NotificationService.instance.reschedule();
    if (mounted) toast(context, 'گروه فعال: ${g.name} ✦');
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

  /// ویرایش درس‌ها: گروه باید فعال باشه چون ویرایشگر روی گروه فعال کار می‌کنه.
  Future<void> _editCourses(CourseGroup g) async {
    await _store.selectGroup(g.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoursesEditorScreen()),
    );
  }

  Future<void> _backupGroup(CourseGroup g) async {
    await _store.selectGroup(g.id);
    final code = encodeBackupCode(_store.exportActiveGroupJson());
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) toast(context, 'کد کوتاه پشتیبان «${g.name}» کپی شد — در بازگردانی همون کد رو بچسبون ✦');
  }

  Future<void> _delete(CourseGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('«${g.name}» پاک بشه؟'),
        content: Text(
          '${fa(g.courses.length)} درس و همهٔ جلسه‌های این گروه پاک می‌شن. '
          'گروه‌های دیگر دست‌نخورده می‌مونن. اگه هنوز پشتیبان نداری، اول «پشتیبان این گروه» رو بگیر.',
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

  // ───────────── صفحه ─────────────

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
            onPressed: _addGroupFlow,
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
                child: Text(
                  'با ضربه روی هر گروه، اون گروه «فعال» می‌شه — یعنی صفحهٔ اصلی، '
                  'جدول هفتگی و امتحان‌های همون گروه نشون داده می‌شه.\n'
                  'از منوی سه‌نقطهٔ هر گروه: تغییر نام، ویرایش درس‌ها، گرفتن پشتیبان و حذف.',
                  style: const TextStyle(color: AppColors.muted, height: 1.7, fontSize: 13),
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
                  onEdit: () => _editCourses(g),
                  onBackup: () => _backupGroup(g),
                  onDelete: () => _delete(g),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.saffron),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      onTap: onTap,
    );
  }
}

class _GroupTile extends StatelessWidget {
  final CourseGroup group;
  final bool active;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onEdit;
  final VoidCallback onBackup;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.active,
    required this.canDelete,
    required this.onSelect,
    required this.onRename,
    required this.onEdit,
    required this.onBackup,
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
                          '${fa(group.sessionCount)} جلسه — برای انتخاب، روی همین ردیف بزن',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'بیشتر',
                  onSelected: (v) {
                    switch (v) {
                      case 'rename':
                        onRename();
                      case 'edit':
                        onEdit();
                      case 'backup':
                        onBackup();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('ویرایش درس‌ها')),
                    const PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                    const PopupMenuItem(value: 'backup', child: Text('پشتیبان این گروه (کپی)')),
                    if (canDelete) const PopupMenuItem(value: 'delete', child: Text('حذف گروه')),
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
