import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

// Assuming these imports exist:
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Auth/auth_screen.dart';
import 'package:shoe_view/analytics_service.dart';
import 'package:shoe_view/app_status_notifier.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['14F56A9612119919309484C5137CFCC8']),
  );
  await fcore.Firebase.initializeApp();
  await InstallSourceTracker.detectAndSetInstallSource();

  if (kReleaseMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    AppLogger.mode = LogMode.loggerAndCrashlytics;
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStatusNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppStatusNotifier>().themeMode;

    return MaterialApp(
      title: 'Shoe View',
      initialRoute: '/',
      routes: {
        '/main': (context) => AuthScreen(),
        // other routes...
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData.dark(),
      themeMode:
          themeMode, // ✅ Use the dynamic theme mode from AppStatusNotifier
      home: const AuthScreen(),
    );
  }
}
