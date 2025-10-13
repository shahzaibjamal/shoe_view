
import 'package:flutter/material.dart';
// --- Auth Loading Stages ---
enum AuthLoadingStage { idle, googleSignIn, firebaseAuth, authorizationCheck }
// ---------------------------

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
