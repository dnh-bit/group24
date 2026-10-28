import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils.dart';
import 'editor/widgets.dart' show toast;

/// دستیار هوشمند — اپ خودش به هیچ هوش مصنوعی وصل نمی‌شود؛
/// فقط یک پرامپت آماده می‌دهد که کاربر همراه PDF یا عکسِ برنامهٔ دانشگاهی‌اش
/// به چت‌بات دلخواهش بدهد؛ خروجی چت‌بات را همین‌جا وارد می‌کند.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  bool _copied = false;
  String _prompt = '';

  /// پرامپت آماده: چت‌بات خودش فایل/تصویر پیوست‌شده را می‌خواند
  /// و برنامه را به فرمت کوتاه اپ برمی‌گرداند.
  String _buildPrompt() {
    return '''تو یک دستیار برنامه‌ریزی درسی هستی. من تصویر یا فایل PDF «برنامهٔ هفتگی» یا «تاییدیهٔ انتخاب واحد» دانشگاهم را پیوست همین پیام کرده‌ام. آن را با دقت بخوان و همهٔ درس‌ها را به فرمت متنی کوتاه زیر تبدیل کن. فقط و فقط همین فرمت را بده، بدون هیچ توضیح اضافه، بدون بلوک کد.

فرمت (هر درس چند خط دارد، جداکننده همیشه | است):

PLAN|name=نام گروه یا ترم
c1|نام کامل درس|نام کوتاه|نام استاد|نوع درس|واحد|شماره رنگ
s|روز|ساعت‌شروع|ساعت‌پایان|مکان|نظری یا عملی
x|سال|ماه|روز|ساعت‌شروع امتحان|ساعت‌پایان امتحان|محل امتحان

قوانین حیاتی:
- خط PLAN فقط یک بار اول می‌آید؛ name = نام کوتاه گروه، مثلاً: ترم اول ۱۴۰۵
- خط cN برای هر درس: N شمارهٔ ترتیبی از ۱ به بعد. نوع درس یکی از: تخصصی / عمومی / معارف / پایه / کارورزی / اختیاری. واحد عدد ۰ تا ۳۰. شمارهٔ رنگ عدد ۰ تا ۱۱ (به سلیقهٔ خودت انتخاب کن).
- خط s برای هر جلسهٔ هفتگی همان درس، بلافاصله بعد از خط c. روز عدد است: ۰=شنبه، ۱=یکشنبه، ۲=دوشنبه، ۳=سه‌شنبه، ۴=چهارشنبه، ۵=پنج‌شنبه، ۶=جمعه. ساعت اعشاری: 7.5 یعنی ۷:۳۰ صبح، 13.5 یعنی ۱۳:۳۰. پایان باید بعد از شروع باشد.
- خط x برای امتحان همان درس (اگر تاریخ امتحان در فایل نیست، خط x را ننویس). تاریخ شمسی است: سال مثل 1405، ماه ۱ تا ۱۲، روز ۱ تا ۳۱. اگر محل امتحان معلوم نیست خالی بگذار.
- اگر چیزی در فایل نامعلوم بود (استاد، مکان کلاس و…) خالی نگذار، بنویس: نامشخص
- داخل هیچ فیلدی نویسهٔ | ننویس. اگر نامی کاما یا خط تیره داشت اشکالی ندارد، فقط | ممنوع.
- هیچ خط اضافه، شماره‌گذاری، توضیح یا عذرخواهی ننویس. خروجی فقط خطوط PLAN و c و s و x است.''';
  }

  Future<void> _copyPrompt() async {
    setState(() {
      _prompt = _buildPrompt();
      _copied = true;
    });
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (mounted) toast(context, 'پرامپت کپی شد — حالا به چت‌باتت بفرستش ✦');
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
          const _StepCard(
            n: 1,
            title: 'فایل برنامهٔ دانشگاهی‌ت رو بردار',
            text: 'برنامهٔ هفتگی یا تاییدیهٔ انتخاب واحدت رو از سایت دانشگاه دانلود کن — PDF یا عکس، هر دو خوبه. لازم نیست متنش رو کپی کنی یا تایپش کنی.',
          ),
          const _StepCard(
            n: 2,
            title: 'پرامپت رو کپی کن و بفرست به چت‌بات',
            text: 'دکمهٔ پایین صفحه رو بزن تا پرامپت آماده کپی بشه. برو تو چت‌باتت (ChatGPT، Gemini، ربات تلگرامی و…)، پرامپت رو بچسبون و فایل برنامه رو هم «پیوست/ضمیمه» همون پیام کن. چت‌بات خودش فایل رو می‌خونه.',
          ),
          const _StepCard(
            n: 3,
            title: 'خروجی چت‌بات رو وارد این برنامه کن',
            text: 'چت‌بات چند خط کوتاه بهت می‌ده (با PLAN شروع می‌شه). همون متن رو کپی کن و برگرد به «گروه‌های درسی ← گروه جدید ← از متن» — یا ذخیره‌اش کن و «از فایل» بزن. برنامه به‌عنوان گروهِ جدید اضافه می‌شه و برنامه‌های قبلی دست‌نخورده می‌مونن.',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.saffron,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _copyPrompt,
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('کپی پرامپت آماده', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (_copied) ...[
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
                '• اگر چت‌باتی که استفاده می‌کنی فایل نمی‌پذیره، ازش بخواه عکس برنامه رو ببینه؛ اکثر چت‌بات‌های معروف عکس می‌فهمن.\n'
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
