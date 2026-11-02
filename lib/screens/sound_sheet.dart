
import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';

/// شیت انتخاب صدای آلارم — با پیش‌نمایش زنده و انتخاب موسیقی از گوشی.
Future<AlarmSound?> showSoundSheet(
  BuildContext context, {
  required AlarmSound current,
}) {
  return showModalBottomSheet<AlarmSound>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _SoundSheet(current: current),
  );
}

class _SoundSheet extends StatefulWidget {
  final AlarmSound current;
  const _SoundSheet({required this.current});

  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  late AlarmSound _selected = widget.current;
  String? _playingUri;

  @override
  void dispose() {
    SoundService.instance.stopPreview();
    super.dispose();
  }

  Future<void> _preview(AlarmSound sound) async {
    final uri = await SoundService.instance.uriFor(sound);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('این گزینه صدا ندارد.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    setState(() => _playingUri = uri);
    await SoundService.instance.preview(uri);
    // نمونه خودش تمام می‌شود؛ فقط نشانگر را برمی‌داریم
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted && _playingUri == uri) setState(() => _playingUri = null);
  }

  /// انتخاب موسیقی با انتخابگر رسمی زنگ اندروید
  Future<void> _pickCustom() async {
    final uri = await SoundService.instance.pickCustomSound();
    if (uri == null) return; // کاربر لغو کرد
    final name = await SoundService.instance.customSoundLabel();
    await SettingsService.instance.update(
      SettingsService.instance.settings.copyWith(
        customSoundUri: uri,
        customSoundName: name,
        alarmSound: AlarmSound.custom,
      ),
    );
    await SoundService.instance.refresh();
    if (!mounted) return;
    setState(() => _selected = AlarmSound.custom);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(name.isEmpty ? 'موسیقی انتخاب شد' : '«$name» انتخاب شد'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customName = SettingsService.instance.settings.customSoundName;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('صدای آلارم',
                    style: TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.saffron)),
              ),
            ),
            for (final v in AlarmSound.values)
              ListTile(
                onTap: () => setState(() => _selected = v),
                leading: Icon(
                  _selected == v ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: _selected == v ? AppColors.saffron : AppColors.line,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(v.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (v == AlarmSound.custom && customName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          customName.length > 18 ? '${customName.substring(0, 16)}…' : customName,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(v.hint, style: const TextStyle(fontSize: 12.5)),
                trailing: (v == AlarmSound.vibrateOnly || v == AlarmSound.silent)
                    ? null
                    : IconButton(
                        tooltip: 'پخش نمونه',
                        icon: Icon(
                          _playingUri == null ? Icons.play_circle_outline_rounded : Icons.graphic_eq_rounded,
                          color: AppColors.saffron,
                        ),
                        onPressed: () => _preview(v),
                      ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: AppColors.olive),
              title: const Text('انتخاب فایل از گوشی', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('MP3، M4A، AAC، WAV، OGG، FLAC',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _pickCustom,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.saffron,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('تأیید', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
