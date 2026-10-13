import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../utils.dart';

Future<double?> pickHour(BuildContext context, double current) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current.floor(), minute: ((current % 1) * 60).round()),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: Directionality(textDirection: TextDirection.rtl, child: child!),
    ),
  );
  if (t == null) return null;
  return hourFrom(t.hour, t.minute);
}

class TimeField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final h = await pickHour(context, value);
          if (h != null) onChanged(h);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          child: Text(fmtTime(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontFamily: kTitleFont, fontSize: 24, color: AppColors.olive)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Card2 extends StatelessWidget {
  final Widget child;
  const Card2({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: child,
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
