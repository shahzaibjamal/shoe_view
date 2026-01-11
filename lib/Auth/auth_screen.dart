import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Auth/auth_loading_splash.dart';
import 'package:shoe_view/Helpers/shoe_response.dart';
import 'package:shoe_view/Helpers/version_footer.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/Auth/home_gate.dart';
import '../Helpers/app_logger.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthLoadingStage _stage = AuthLoadingStage.idle;
  String? _error;
  bool _signedIn = false;
  String? _email;

  late final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseService _firebaseService = FirebaseService();

  static const String kAuthorizedKey = 'is_locally_authorized';
  static const String kCachedEmailKey = 'cached_user_email';
  static const String kTestPermissionKey = 'isTestModeEnabled_Permission';

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();

      final bool wasAuthorized = prefs.getBool(kAuthorizedKey) ?? false;
      final String? cachedEmail = prefs.getString(kCachedEmailKey);

      if (user != null && wasAuthorized && user.email == cachedEmail) {
        AppLogger.log("Offline Flow: Quick-entering for ${user.email}");

        // 1. Load settings into Notifier
        if (mounted) await _loadPrefsInNotifier();

        // 2. Immediate Navigation
        _navigateToHome();

        // 3. Background Sync
        _backgroundSync(user);
      } else {
        _initGoogleSignIn();
      }
    });
  }

  void _initGoogleSignIn() {
    try {
      final clientId = dotenv.env['CLIENT_ID'];
      final serverClientId = dotenv.env['SERVER_CLIENT_ID'];
      _googleSignIn
          .initialize(clientId: clientId, serverClientId: serverClientId)
          .then((_) {
            _googleSignIn.authenticationEvents
                .listen(_handleAuthenticationEvent)
                .onError(_handleAuthenticationError);
          });
    } catch (e, stack) {
      AppLogger.log('Google Init Crash: $e\n$stack');
    }
  }

  void _handleAuthenticationEvent(event) {
    Future<void>(() async {
      final user = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
        _ => null,
      };

      if (user != null) {
        if (mounted) {
          setState(() {
            _stage = AuthLoadingStage.firebaseAuth;
            _signedIn = true;
            _email = user.email;
            _error = null;
          });
        }

        try {
          final googleAuth = await user.authentication;
          final credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken:
                googleAuth.idToken, // Fixed typo: was using idToken twice
          );

          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final firebaseUser = userCredential.user;
          final String email = firebaseUser?.email ?? user.email;
          final String? idToken = await firebaseUser?.getIdToken();

          if (mounted)
            setState(() => _stage = AuthLoadingStage.authorizationCheck);

          if (idToken != null) {
            await _callCheckUserAuthorization(email, idToken);
          }
        } catch (e) {
          _handleAuthenticationError(e);
        }
      } else {
        if (mounted) {
          setState(() {
            _stage = AuthLoadingStage.idle;
            _signedIn = false;
          });
        }
      }
    });
  }

  Future<void> _callCheckUserAuthorization(
    String email,
    String idToken, {
    bool isBackground = false,
  }) async {
    // Capture the notifier while the screen is still active
    final notifier = context.read<AppStatusNotifier>();

    try {
      final result = await _firebaseService.checkUserAuthorization(
        email: email,
        idToken: idToken,
      );
      final shoeResponse = ShoeResponse.fromJson(result);

      // 🎯 BUSINESS LOGIC: We pass the data to the Notifier.
      // This will work even if AuthScreen is destroyed 1 millisecond later.
      notifier.updateFromResponse(shoeResponse, email);

      // PERSISTENCE: Save the keys we need for the next offline launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kAuthorizedKey, shoeResponse.isAuthorized);
      await prefs.setString(kCachedEmailKey, email);
      await prefs.setBool(
        'isTestModeEnabled_Permission',
        shoeResponse.isTestModeEnabled,
      );

      // UI LOGIC: Only run if the user is still looking at this screen
      if (!isBackground && mounted) {
        if (shoeResponse.isAuthorized) {
          _navigateToHome();
        } else {
          _handleUnauthorized();
        }
      }
    } catch (e) {
      AppLogger.log("Network logic failed: $e");
      // Handle offline fallback...
    }
  }

  Future<void> _backgroundSync(User user) async {
    try {
      final String? idToken = await user.getIdToken();
      if (idToken != null) {
        await _callCheckUserAuthorization(
          user.email!,
          idToken,
          isBackground: true,
        );
      }
    } catch (_) {}
  }

  void _handleAuthenticationError(error) {
    AppLogger.log("Authentication Error: $error");
    if (mounted) {
      setState(() {
        _error = "Sign-in failed. Please check your connection.";
        _signedIn = false;
        _stage = AuthLoadingStage.idle;
      });
    }
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
      _handleAuthenticationError(e);
    }
  }

  Future<void> _signOut() async {
    if (mounted) setState(() => _stage = AuthLoadingStage.googleSignIn);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kAuthorizedKey, false);
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      AppLogger.log('SignOut error: $e');
    }
    if (mounted) {
      setState(() {
        _stage = AuthLoadingStage.idle;
        _signedIn = false;
        _email = null;
      });
    }
  }

  void _handleUnauthorized() async {
    if (mounted) {
      setState(() {
        _error = 'User is not authorized to access the shoe data.';
        _signedIn = false;
        _stage = AuthLoadingStage.idle;
      });
    }
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
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
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final appStatusNotifier = context.read<AppStatusNotifier>();

    final themeString = prefs.getString('themeMode') ?? 'Light';

    // We also pull the test permission here for UI consistency
    final bool hasTestPermission = prefs.getBool(kTestPermissionKey) ?? false;
    appStatusNotifier.updateTestModeEnabled(hasTestPermission);

    ThemeMode themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == themeString,
      orElse: () => ThemeMode.light,
    );

    appStatusNotifier.updateAllSettings(
      themeMode: themeMode,
      currencyCode: prefs.getString('currency') ?? 'USD',
      isMultiSize: prefs.getBool('multiSize') ?? false,
      isTest: prefs.getBool('isTest') ?? false,
      isSalePrice: prefs.getBool('isSalePrice') ?? false,
      isRepairedInfoAvailable: prefs.getBool('isRepairedInfoAvailable') ?? true,
      isHighResCollage: prefs.getBool('isHighResCollage') ?? false,
      isAllShoesShare: prefs.getBool('isAllShoesShare') ?? false,
      sampleShareCount: prefs.getInt('sampleShareCount') ?? 0,
      isFlatSale: prefs.getBool('isFlatSale') ?? false,
      lowDiscount: prefs.getDouble('lowDiscount') ?? 0,
      highDiscount: prefs.getDouble('highDiscount') ?? 0,
      flatDiscount: prefs.getDouble('flatDiscount') ?? 0,
      isPriceHidden: prefs.getBool('isPriceHidden') ?? false,
      isInfoCopied: prefs.getBool('isInfoCopied') ?? false,
    );
  }

  String get _loadingMessage => switch (_stage) {
    AuthLoadingStage.googleSignIn => 'Connecting to Google...',
    AuthLoadingStage.firebaseAuth => 'Securing connection...',
    AuthLoadingStage.authorizationCheck => 'Checking user permissions...',
    _ => '',
  };

  double get _progress => switch (_stage) {
    AuthLoadingStage.googleSignIn => 0.33,
    AuthLoadingStage.firebaseAuth => 0.66,
    AuthLoadingStage.authorizationCheck => 0.95,
    _ => 0.0,
  };

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _stage != AuthLoadingStage.idle;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (!isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_signedIn)
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
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ),
                    if (_signedIn)
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
                    if (_signedIn && _email != null)
                      Text('Signed in as $_email'),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: VersionFooter(),
            ),
          ),
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
