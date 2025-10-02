import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shoe_view/shoe_response.dart';
import 'shoe_list_view.dart';
import 'app_status_notifier.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fcore.Firebase.initializeApp();
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.playIntegrity,
  // );

 final debugProvider = AndroidDebugProvider(debugToken: '88E15778-3EEC-4586-AB37-2F44D5F39CA3');
  await FirebaseAppCheck.instance.activate(
    providerAndroid: debugProvider
  );

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
    return MaterialApp(
      title: 'Shoe View',
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
  bool _loading = false;
  String? _error;
  bool _signedIn = false;
  String? _email;
  late final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is already signed in — skip auth flow
        setState(() {
          _loading = true;
        });
        final String? idToken = await user?.getIdToken();
        final String? email = user.email;

        if (idToken != null && email != null) {
          await _callCheckUserAuthorization(email, idToken);
        }
      } else {
        // Show sign-in screen

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
          print('initState crash: $e\n$stack');
        }
      }
    });
  }

  void _handleAuthenticationEvent(event) {
    print('GoogleSignIn event type: ${event.runtimeType}');
    print('Full event object: $event');
    // Extract user and idToken using event-based API
    Future<void>(() async {
      final user = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
        _ => null,
      };
      if (user != null) {
        // Use GoogleSignInAccount to get GoogleAuthProvider credential
        final googleAuth = user.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.idToken,
        );
        // Sign in to Firebase
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final firebaseUser = userCredential.user;
        final String email = firebaseUser?.email ?? user.email;
        // Get Firebase ID token
        final String? idToken = await firebaseUser?.getIdToken();
        print('Firebase ID token: $idToken');
        setState(() {
          _signedIn = true;
          _email = email;
          _error = null;
          _loading = true;
        });
        if (idToken != null) {
          await _callCheckUserAuthorization(email, idToken);
        }
      } else {
        setState(() {
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
    });
  }

  void _triggerSignIn() async {
    print('Google Sign-In button pressed');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _googleSignIn.attemptLightweightAuthentication();
      print('GoogleSignIn.attemptLightweightAuthentication called');
    } catch (e, stack) {
      print('GoogleSignIn error: $e\n$stack');
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _signOut() async {
    print('Sign out button pressed');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _googleSignIn.signOut();
      print('GoogleSignIn.signOut called');
      setState(() {
        _signedIn = false;
        _email = null;
      });
    } catch (e, stack) {
      print('SignOut error: $e\n$stack');
      setState(() {
        _error = e.toString();
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _callCheckUserAuthorization(String email, String idToken) async {
    final isTest = false;
    _loading = isTest;
    final result = await FirebaseFunctions.instance
        .httpsCallable('checkUserAuthorization')
        .call({'email': email, 'idToken': idToken, 'isTest': isTest});
    print('checkUserAuthorization response: ${result.data}');
    // Assuming 'result' is the raw map from your Firebase function call
    final rawData = result.data as Map<String, dynamic>;
    final shoeResponse = ShoeResponse.fromJson(rawData);

    print(
      'isTrial - ${shoeResponse.isTrial} isAuthorized - ${shoeResponse.isAuthorized} trialStartedMillis - ${shoeResponse.trialStartedMillis} lastLoginMillis - ${shoeResponse.lastLoginMillis}',
    );
    context.read<AppStatusNotifier>().updateTrial(shoeResponse.isTrial);
    if (!shoeResponse.isAuthorized) {
      setState(() {
        _error = 'User is not authorized to access the shoe data.';
        _signedIn = false;
        _email = null;
        _loading = false;
      });
      await _googleSignIn.signOut();
      return;
    }
    _navigateToHome();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ShoeListView(initialShoes: [])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_signedIn) ...[
                    ElevatedButton(
                      onPressed: _triggerSignIn,
                      child: const Text('Sign in with Google'),
                    ),
                  ],
                  ElevatedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                  if (_signedIn) Text('Signed in as $_email'),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
