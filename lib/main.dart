import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/schedule_store.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  await ScheduleStore.instance.load();
  await NotificationService.instance.init();
  runApp(const Group24App());
}

class Group24App extends StatelessWidget {
  const Group24App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامه درسی',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
