import 'dart:ui';
import 'package:flutter/material.dart';

class QuotaCircle extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final Color color;

  const QuotaCircle({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.color = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (limit > 0) ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6, // Slightly thinner for a cleaner look
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            // --- Fractional Center View ---
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$used',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18, // Slightly smaller to fit above the dash
                    height: 1.2,
                  ),
                ),
                Container(
                  width: 18, // The "Dash" width
                  height: 1.5, // The "Dash" thickness
                  color: Colors.grey[400],
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
                Text(
                  '$limit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
