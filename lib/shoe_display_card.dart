import 'package:flutter/material.dart';

class SizeDisplayCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool isBound;

  const SizeDisplayCard({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.isBound = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color borderColor = onTap == null
        ? Theme.of(context).dividerColor.withOpacity(0.1)
        : isBound
            ? Theme.of(context).primaryColor
            : Theme.of(context).dividerColor.withOpacity(0.2);

    final Color bgColor = onTap == null
        ? (isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100)
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.white);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isBound ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(8.0),
          color: bgColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value, 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
