import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/schedule_store.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils.dart';

/// دیالوگ «پیست متن خروجی چت‌بات».
///
/// کاربر متن را می‌چسباند، پیش‌نمایش می‌بیند (چند درس/جلسه/امتحان) و با یک
/// دکمه به‌عنوان گروه جدید وارد می‌کند. همهٔ قالب‌های پشتیبانی‌شده قبولند:
/// فرمت خطی PLAN|، JSON، آرایهٔ بدون پوشش و کد CP2.
Future<bool> showPasteImportSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _PasteSheet(),
  );
  return ok ?? false;
}

class _PasteSheet extends StatefulWidget {
  const _PasteSheet();

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  String? _error;
  String? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // اگر متنی در کلیپ‌بورد هست، خودکار پر کن تا کاربر فقط تأیید کند
    WidgetsBinding.instance.addPostFrameCallback((_) => _autofillFromClipboard());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _autofillFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted || text.length < 10 || _ctrl.text.isNotEmpty) return;
      // فقط اگر شبیه خروجی برنامه باشد
      final looksLikePlan = text.contains('PLAN|') ||
          text.contains('"courses"') ||
          text.contains('"plan"') ||
          text.startsWith('CP2:') ||
          text.contains('{');
      if (!looksLikePlan) return;
      _ctrl.text = text;
      _analyze();
    } catch (_) {
      // دسترسی به کلیپ‌بورد نبود — مهم نیست، دستی می‌چسباند
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() => _error = 'کلیپ‌بورد خالی است.');
        return;
      }
      _ctrl.text = text;
      _analyze();
    } catch (e) {
      setState(() => _error = 'خواندن کلیپ‌بورد نشد: $e');
    }
  }

  /// پیش‌نمایش بدون تغییر داده: فقط می‌گوید چند درس/جلسه/امتحان پیدا شد.
  void _analyze() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    try {
      final parsed = ScheduleStore.instance.parseAnyToGroups(text);
      final courses = parsed.groups.first.courses;
      if (courses.isEmpty) {
        setState(() {
          _preview = null;
          _error = 'هیچ درسی در این متن پیدا نشد.';
        });
        return;
      }
      final sessions = courses.fold<int>(0, (s, c) => s + c.sessions.length);
      final exams = courses.where((c) => c.exam != null).length;
      final units = courses.fold<int>(0, (s, c) => s + c.units);
      final name = parsed.suggestedName.trim();
      setState(() {
        _error = null;
        _preview = '${fa(courses.length)} درس · ${fa(sessions)} جلسه · '
            '${fa(exams)} امتحان · ${fa(units)} واحد'
            '${name.isEmpty ? '' : '\nنام: «$name»'}';
      });
    } catch (e) {
      setState(() {
        _preview = null;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString().replaceFirst('FormatException: ', '');
    if (s.contains('هیچ درسی')) return 'این متن هیچ درسی ندارد. مطمئن شو کل خروجی چت‌بات را کپی کرده‌ای.';
    if (s.contains('JSON')) return 'متن شبیه JSON است ولی کامل نیست — احتمالاً نصفه کپی شده.';
    return s;
  }

  Future<void> _import() async {
    if (_busy) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'اول متن را بچسبان.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await ScheduleStore.instance.importAsNewGroup(text);
      await NotificationService.instance.reschedule();
      if (!mounted) return;
      // قبل از بستن شیت، پیام را روی ریشه بگیر
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('«${group.name}» با ${fa(group.courses.length)} درس اضافه شد ✦'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendly(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text('پیست متن برنامه',
                style: TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
          ),
          const SizedBox(height: 4),
          const Text(
            'خروجی چت‌بات را همین‌جا بچسبان. فرمت PLAN|، JSON و کد CP2 هر سه قبول‌اند.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.7),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            minLines: 6,
            maxLines: 12,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
            decoration: InputDecoration(
              hintText: 'PLAN|name=ترم اول ۱۴۰۵\nc1|نام درس|کوتاه|استاد|تخصصی|2|0\ns|0|8|10|کلاس ۲۰۴|نظری',
              hintStyle: const TextStyle(fontSize: 11, height: 1.5),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'چسباندن از کلیپ‌بورد',
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                    onPressed: _pasteFromClipboard,
                  ),
                  IconButton(
                    tooltip: 'پاک کردن',
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      _analyze();
                    },
                  ),
                ],
              ),
            ),
            onChanged: (_) => _analyze(),
          ),
          const SizedBox(height: 10),

          // پیش‌نمایش
          if (_preview != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.olive.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.olive.withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.olive, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_preview!,
                        style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.olive)),
                  ),
                ],
              ),
            ),

          // خطا
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(70)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(_error!,
                        style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.red)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy || _preview == null ? null : _import,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.saffron,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('وارد کن به‌عنوان گروه جدید',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'برنامه‌های قبلی دست‌نخورده می‌مانند.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
