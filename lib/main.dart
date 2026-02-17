import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

// Assuming these imports exist:
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Auth/auth_screen.dart';
import 'package:shoe_view/Services/analytics_service.dart';
import 'package:shoe_view/Services/transaction_history_service.dart';
import 'package:shoe_view/app_status_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Transaction History (Hive)
  await TransactionHistoryService().init();
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  MobileAds.instance.initialize();
  // MobileAds.instance.updateRequestConfiguration(
  //   RequestConfiguration(testDeviceIds: ['14F56A9612119919309484C5137CFCC8']),
  // );
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
  await dotenv.load(fileName: ".env");
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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
          primary: Colors.indigo.shade600,
          secondary: Colors.indigoAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Ultra light slate
        // Consistent text styles
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
          bodySmall: TextStyle(fontSize: 12, color: Colors.black45),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8), // Indigo 400 (Vibrant but soft for dark)
          onPrimary: Colors.white,
          secondary: const Color(0xFF6366F1), // Indigo 500
          onSecondary: Colors.white,
          surface: const Color(0xFF1E293B), // Slate 800
          onSurface: const Color(0xFFF1F5F9), // Slate 100
          background: const Color(0xFF0F172A), // Slate 900
          onBackground: const Color(0xFFF8FAFC), // Slate 50
          primaryContainer: const Color(0xFF312E81), // Indigo 900
          onPrimaryContainer: const Color(0xFFE0E7FF), // Indigo 100
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        dividerColor: Colors.white.withOpacity(0.12),
        // Better Text hierarchy for Dark Mode
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Color(0xFFF8FAFC),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Color(0xFFF8FAFC),
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFF1F5F9)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
          bodySmall: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF334155), // Slate 700
          selectedColor: const Color(0xFF4F46E5), // Indigo 600
          disabledColor: Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          labelStyle: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13),
          secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E293B),
        ),
      ),
      themeMode: themeMode,
      home: const AuthScreen(),
    );
  }
}
