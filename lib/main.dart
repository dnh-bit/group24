import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/schedule_store.dart';
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // نوار وضعیت و نوار ناوبری پایین سیستم هم رنگ پس‌زمینهٔ اپ بشن (نه مشکی)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.paper,
    systemNavigationBarDividerColor: AppColors.line,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // اندروید ۱۵ و بالاتر: محتوا تا زیر نوارهای سیستم کشیده می‌شه تا رنگ پس‌زمینهٔ اپ دیده بشه
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SettingsService.instance.load();
  await ScheduleStore.instance.load();
  await NotificationService.instance.init();
  NotificationService.onNotificationTap = _routeNotificationTap;
  NotificationService.onSnooze = (payload, minutes) =>
      NotificationService.instance.snooze(payload, minutes);
  runApp(const Group24App());
}

/// دکمهٔ «۵ دقیقهٔ دیگر» روی آلارم: همان اعلان ۵ دقیقه بعد دوباره می‌آید.
/// (سرویس خودش آلارم را می‌چیند؛ اینجا فقط ثبت می‌شود.)

/// ضربهٔ کاربر روی اعلان: گروهِ برنامهٔ اعلان فعال می‌شه و کارتِ همان درس باز می‌شه.
void _routeNotificationTap(String payload) {
  _openNotificationCourse(payload);
}

/// مسیریابی payload اعلان → صفحهٔ برنامه با کارت همان درس.
Future<void> _openNotificationCourse(String payload) async {
  final id = int.tryParse(payload.split(':')[1]);
  if (id == null) return;

  final nav = Group24App.navigatorKey.currentState;
  if (nav == null) {
    // شروع سرد: هنوز navigator آماده نیست → بعد از اولین فریم باز می‌شود
    NotificationService.pendingTap = payload;
    return;
  }

  // اعلان متعلق به همان گروهی است که در تنظیمات برای اعلان انتخاب شده
  final store = ScheduleStore.instance;
  await store.selectGroup(store.groupForNotifications().id);
  nav.push(MaterialPageRoute(builder: (_) => ScheduleScreen(focusCourseId: id)));
}

/// اگر ضربهٔ اعلان قبل از آماده شدن navigator ذخیره شده بود، بعد از اولین فریم باز می‌شود.
Future<void> flushPendingNotificationRoute() async {
  final payload = NotificationService.pendingTap;
  if (payload == null) return;
  NotificationService.pendingTap = null;
  await _openNotificationCourse(payload);
}

class Group24App extends StatefulWidget {
  const Group24App({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<Group24App> createState() => _Group24AppState();
}

class _Group24AppState extends State<Group24App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.pendingTap != null) {
        flushPendingNotificationRoute();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامه درسی',
      debugShowCheckedModeBanner: false,
      navigatorKey: Group24App.navigatorKey,
      theme: buildTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.paper,
          systemNavigationBarDividerColor: AppColors.line,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
