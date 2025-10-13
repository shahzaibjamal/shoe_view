import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Assuming these imports exist:
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/version_footer.dart';
import 'package:shoe_view/Helpers/shoe_response.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:shoe_view/home_gate.dart';
import 'package:shoe_view/app_status_notifier.dart';

// --- Auth Loading Stages ---
enum AuthLoadingStage { idle, googleSignIn, firebaseAuth, authorizationCheck }
// ---------------------------

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
  // const String debugToken = '88E15778-3EEC-4586-AB37-2F44D5F39CA3';

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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthLoadingStage _stage = AuthLoadingStage.idle;

  String get _loadingMessage {
    switch (_stage) {
      case AuthLoadingStage.googleSignIn:
        return 'Connecting to Google...';
      case AuthLoadingStage.firebaseAuth:
        return 'Securing connection...';
      case AuthLoadingStage.authorizationCheck:
        return 'Checking user permissions...';
      case AuthLoadingStage.idle:
        return '';
    }
  }

  double get _progress {
    switch (_stage) {
      case AuthLoadingStage.googleSignIn:
        return 0.33;
      case AuthLoadingStage.firebaseAuth:
        return 0.66;
      case AuthLoadingStage.authorizationCheck:
        return 0.95;
      case AuthLoadingStage.idle:
        return 0.0;
    }
  }

  String? _error;
  bool _signedIn = false;
  String? _email;
  late final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _stage = AuthLoadingStage.authorizationCheck;
        });
        final String? idToken = await user.getIdToken();
        final String? email = user.email;

        if (idToken != null && email != null) {
          await _callCheckUserAuthorization(email, idToken);
        } else {
          setState(() {
            _stage = AuthLoadingStage.idle;
          });
        }
      } else {
        try {
          _googleSignIn
              .initialize(
                clientId:
                    '208115481751-nhcu2josbkqrdq2tcje0krn5hmuat0n1.apps.googleusercontent.com',
                serverClientId:
                    '208115481751-6021ik4oq3deeabsfs6ns31v4hkrim3v.apps.googleusercontent.com',
              )
              .then((_) {
                _googleSignIn.authenticationEvents
                    .listen(_handleAuthenticationEvent)
                    .onError(_handleAuthenticationError);
              });
        } catch (e, stack) {
          AppLogger.log('initState crash: $e\n$stack');
        }
      }
    });
  }

  void _handleAuthenticationEvent(event) {
    Future<void>(() async {
      final user = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
        _ => null,
      };
      if (user != null) {
        setState(() {
          _stage = AuthLoadingStage.firebaseAuth;
          _signedIn = true;
          _email = user.email;
          _error = null;
        });

        final googleAuth = user.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final firebaseUser = userCredential.user;
        final String email = firebaseUser?.email ?? user.email;
        final String? idToken = await firebaseUser?.getIdToken();

        setState(() {
          _stage = AuthLoadingStage.authorizationCheck;
        });

        if (idToken != null) {
          await _callCheckUserAuthorization(email, idToken);
        }
      } else {
        setState(() {
          _stage = AuthLoadingStage.idle;
          _signedIn = false;
          _email = null;
        });
      }
    });
  }

  void _handleAuthenticationError(error) {
    setState(() {
      _error = error.toString();
      _signedIn = false;
      _stage = AuthLoadingStage.idle;
    });
  }

  void _triggerSignIn() async {
    setState(() {
      _stage = AuthLoadingStage.googleSignIn;
      _error = null;
    });
    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (e, stack) {
      AppLogger.log('GoogleSignIn error: $e\n$stack');
      setState(() {
        _error = e.toString();
        _stage = AuthLoadingStage.idle;
      });
    }
  }

  void _signOut() async {
    setState(() {
      _stage = AuthLoadingStage.googleSignIn;
      _error = null;
    });
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e, stack) {
      AppLogger.log('SignOut error: $e\n$stack');
      setState(() {
        _error = e.toString();
      });
    }
    setState(() {
      _stage = AuthLoadingStage.idle;
      _signedIn = false;
      _email = null;
    });
  }

  Future<void> _callCheckUserAuthorization(String email, String idToken) async {
    final result = await _firebaseService.checkUserAuthorization(
      email: email,
      idToken: idToken,
    );
    final shoeResponse = ShoeResponse.fromJson(result);
    final appStatusNotifier = context.read<AppStatusNotifier>();
    appStatusNotifier.updateTrial(shoeResponse.isTrial);
    appStatusNotifier.updateTestModeEnabled(shoeResponse.isTestModeEnabled);
    appStatusNotifier.updateDailyShares(shoeResponse.dailySharesUsed);
    appStatusNotifier.updateDailySharesLimit(shoeResponse.dailySharesLimit);
    appStatusNotifier.updateDailyWrites(shoeResponse.dailyWritesUsed);
    appStatusNotifier.updateDailyWritesLimit(shoeResponse.dailyWritesLimit);
    appStatusNotifier.updateTier(shoeResponse.tier);
    appStatusNotifier.updateMultiSizeMode(shoeResponse.isMultiSize);
    appStatusNotifier.updateCurrencyCode(shoeResponse.currencyCode);

    if (!shoeResponse.isAuthorized) {
      setState(() {
        _error = 'User is not authorized to access the shoe data.';
        _signedIn = false;
        _email = null;
        _stage = AuthLoadingStage.idle;
      });
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      return;
    }
    _navigateToHome();
    _loadPrefsInNotifier();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeGate(firebaseService: _firebaseService),
        ),
      );
    }
  }

  Future<void> _loadPrefsInNotifier() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'Light';
    final isTest = prefs.getBool('isTest') ?? false;

    final appStatusNotifier = context.read<AppStatusNotifier>();
    ThemeMode themeMode = ThemeMode.light;
    themeMode = ThemeMode.values.firstWhere((m) => m.name == themeString);
    appStatusNotifier.updateThemeMode(themeMode);
    appStatusNotifier.updateTest(isTest);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _stage != AuthLoadingStage.idle;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Content layer (Sign-in buttons, errors, etc.) - Only visible when not loading
          if (!isLoading)
            Center(
              // Buttons are correctly centered here!
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_signedIn) ...[
                      // Google Sign-In Button
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _triggerSignIn,
                          icon: Image.asset('assets/google.png', height: 24.0),
                          label: const Text(
                            'Sign in with Google',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sign Out Button
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    if (_signedIn) Text('Signed in as $_email'),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

          // Footer is always at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: VersionFooter(),
            ),
          ),

          // Loading Splash Overlay (visible when loading)
          if (isLoading)
            AuthLoadingSplash(
              stage: _stage,
              message: _loadingMessage,
              progress: _progress,
            ),
        ],
      ),
    );
  }
}

// 🎯 WIDGET FOR BRANDED LOADING SCREEN WITH SMOOTHER LERPING PROGRESS BAR
class AuthLoadingSplash extends StatelessWidget {
  final AuthLoadingStage stage;
  final String message;
  final double progress;

  const AuthLoadingSplash({
    super.key,
    required this.stage,
    required this.message,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool showSpinner = stage != AuthLoadingStage.idle;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // S hoe V iew Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // S(hoe)
              Text(
                'S',
                style: TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                  height: 0.8,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2.0, right: 10.0),
                child: Text(
                  'hoe',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: primaryColor.withOpacity(0.6),
                  ),
                ),
              ),
              // V iew
              Text(
                'V',
                style: TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                  height: 0.8,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0.0),
                child: Text(
                  'iew',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: primaryColor.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 50),

          // Progress Indicator and Message Container
          if (showSpinner) ...[
            Text(
              message,
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),

            // LERPING Progress Bar - Smoother Transition (1000ms)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(
                  milliseconds: 1000,
                ), // Increased to 1 second for smoothness
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: primaryColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
