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
    final Color borderColor = onTap == null
        ? Colors.grey.shade300
        : isBound
        ? Theme.of(context).primaryColor
        : Colors.grey.shade400;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isBound ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(8.0),
          color: onTap == null ? Colors.grey.shade200 : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 0),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
