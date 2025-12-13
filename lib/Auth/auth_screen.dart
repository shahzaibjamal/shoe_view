import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    appStatusNotifier.updatePurchasedOffer(shoeResponse.purchasedOffer);
    appStatusNotifier.updateEmail(email);

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
    final sampleShareCount = prefs.getInt('sampleShareCount') ?? 0;
    final isSalePrice = prefs.getBool('isSalePrice') ?? false;

    final appStatusNotifier = context.read<AppStatusNotifier>();
    ThemeMode themeMode = ThemeMode.light;
    themeMode = ThemeMode.values.firstWhere((m) => m.name == themeString);
    appStatusNotifier.updateThemeMode(themeMode);
    appStatusNotifier.updateTest(isTest);
    appStatusNotifier.updateSampleShareCount(sampleShareCount);
    appStatusNotifier.updateSalePrice(isSalePrice);
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
