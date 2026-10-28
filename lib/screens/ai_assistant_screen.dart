import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils.dart';
import 'editor/widgets.dart' show toast;

/// دستیار هوشمند — اپ خودش به هیچ هوش مصنوعی وصل نمی‌شود؛
/// فقط پرامپت آماده می‌سازد و راهنمایی می‌کند که کاربر برنامهٔ دانشگاهی خودش
/// را به چت‌بات دلخواهش بدهد و خروجی را اینجا وارد کند.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _raw = TextEditingController();
  bool _showPrompt = false;
  String _prompt = '';

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  String _buildPrompt(String scheduleText) {
    return '''تو یک دستیار برنامه‌ریزی درسی هستی. برنامهٔ درسی دانشگاه من (در انتهای پیام) را به فرمت متنی کوتاه زیر تبدیل کن. فقط و فقط همین فرمت را بده، بدون هیچ توضیح اضافه، بدون بلوک کد.

فرمت (هر درس چند خط دارد، جداکننده همیشه | است):

PLAN|name=نام گروه یا ترم
c1|نام کامل درس|نام کوتاه|نام استاد|نوع درس|واحد|شماره رنگ
s|روز|ساعت‌شروع|ساعت‌پایان|مکان|نظری یا عملی
x|سال|ماه|روز|ساعت‌شروع امتحان|ساعت‌پایان امتحان|محل امتحان

قوانین حیاتی:
- خط PLAN فقط یک بار اول می‌آید؛ name = نام کوتاه گروه، مثلاً: ترم اول ۱۴۰۵
- خط cN برای هر درس: N شمارهٔ ترتیبی از ۱ به بعد. نوع درس یکی از: تخصصی / عمومی / معارف / پایه / کارورزی / اختیاری. واحد عدد ۰ تا ۳۰. شمارهٔ رنگ عدد ۰ تا ۱۱ (به سلیقهٔ خودت انتخاب کن).
- خط s برای هر جلسهٔ هفتگی همان درس، بلافاصله بعد از خط c. روز عدد است: ۰=شنبه، ۱=یکشنبه، ۲=دوشنبه، ۳=سه‌شنبه، ۴=چهارشنبه، ۵=پنج‌شنبه، ۶=جمعه. ساعت اعشاری: 7.5 یعنی ۷:۳۰ صبح، 13.5 یعنی ۱۳:۳۰. پایان باید بعد از شروع باشد.
- خط x برای امتحان همان درس (اگر تاریخ امتحان معلوم نیست، خط x را ننویس). تاریخ شمسی است: سال مثل 1405، ماه ۱ تا ۱۲، روز ۱ تا ۳۱. اگر محل امتحان معلوم نیست خالی بگذار.
- داخل هیچ فیلدی نویسهٔ | ننویس. اگر نامی کاما یا خط تیره داشت اشکالی ندارد، فقط | ممنوع.
- اگر مکان کلاس در برنامه نبود بنویس: نامشخص
- هیچ خط اضافه، شماره‌گذاری، توضیح یا عذرخواهی ننویس. خروجی فقط خطوط PLAN و c و s و x است.

برنامهٔ درسی دانشگاه من:
$scheduleText''';
  }

  Future<void> _copyPrompt() async {
    final text = _raw.text.trim();
    if (text.isEmpty) {
      toast(context, 'اول برنامهٔ دانشگاهی‌ت رو در کادر بالا بچسبون');
      return;
    }
    setState(() {
      _prompt = _buildPrompt(text);
      _showPrompt = true;
    });
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (mounted) toast(context, 'پرامپت کپی شد — حالا بفرستش به چت‌بات ✦');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دستیار هوشمند', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _StepCard(
            n: 1,
            title: 'برنامهٔ دانشگاهی‌ت رو پیدا کن',
            text: 'برنامهٔ هفتگی یا تاییدیهٔ انتخاب واحدت رو از سایت دانشگاه یا ایمیلی که گرفتی باز کن و کل متنش رو کپی کن. شکلش مهم نیست — همین‌قدر که اسم درس، استاد، روز و ساعت و کلاس توش باشه کافیه.',
          ),
          _StepCard(
            n: 2,
            title: 'متنش رو اینجا بچسبون و پرامپت بگیر',
            text: 'متن رو در کادر زیر بچسبون و دکمهٔ «ساخت پرامپت» رو بزن. پرامپت آماده رو کپی کن و به هر چت‌باتی که داری (ChatGPT، Gemini، ربات تلگرامی و…) بفرست.',
          ),
          _StepCard(
            n: 3,
            title: 'خروجی چت‌بات رو وارد این برنامه کن',
            text: 'چت‌بات چند خط کوتاه بهت می‌ده (با PLAN شروع می‌شه). همون متن رو کپی کن و برگرد به «گروه‌های درسی ← گروه جدید ← از متن» — یا ذخیره‌اش کن و «از فایل» بزن. برنامه به‌عنوان گروهِ جدید اضافه می‌شه و برنامه‌های قبلی دست‌نخورده می‌مونن.',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _raw,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'برنامهٔ هفتگی یا تاییدیهٔ انتخاب واحد دانشگاهت رو اینجا بچسبون…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.saffron,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _copyPrompt,
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('ساخت پرامپت و کپی', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (_showPrompt) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('پرامپت آماده (کپی شده ✓)',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: 'کپی دوباره',
                          icon: const Icon(Icons.content_copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _prompt));
                            toast(context, 'کپی شد ✦');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _prompt,
                      style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted),
                      maxLines: 12,
                      overflow: TextOverflow.fade,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'چند نکته:\n'
                '• این برنامه هیچ داده‌ای به هیچ هوش مصنوعی نمی‌فرسته — خودت انتخاب می‌کنی کدوم چت‌بات و چی بفرستی.\n'
                '• خروجی چت‌بات لازم نیست یک‌دست باشه؛ اگر توضیح اضافه یا بلوک کد هم داشت، موقع وارد کردن خودش تمیزش می‌کنیم.\n'
                '• اگر چت‌بات اشتباهی روز یا ساعت داد، بعد از وارد کردن می‌تونی هر درس رو دستی ویرایش کنی.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int n;
  final String title;
  final String text;
  const _StepCard({required this.n, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.saffron, shape: BoxShape.circle),
                child: Text(fa(n), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(text, style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted)),
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
