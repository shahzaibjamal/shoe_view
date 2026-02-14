
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
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 👟 Logo Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'KICK',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.indigo.shade900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'HIVE',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: primaryColor,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 60),

          // 🔄 Progress Section
          if (showSpinner) ...[
            Text(
              message.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : Colors.indigo.shade200,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),

            // Premium Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60.0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOutSine,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
