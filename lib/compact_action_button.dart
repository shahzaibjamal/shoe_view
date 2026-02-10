import 'package:flutter/material.dart';

/// A compact action button with a subtle press animation.
/// Shows checkmark success animation only for "copy" actions.
class CompactActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final bool showSuccessCheck; // Only true for copy actions

  const CompactActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.showSuccessCheck = false,
  });

  @override
  State<CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<CompactActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    // Play scale down animation
    await _controller.forward();
    await _controller.reverse();

    widget.onPressed();

    // Only show success check for copy actions
    if (widget.showSuccessCheck && mounted) {
      setState(() => _isSuccess = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _isSuccess = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _isSuccess
              ? Colors.green.withOpacity(0.15)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _isSuccess ? Icons.check_circle_rounded : widget.icon,
              key: ValueKey(_isSuccess),
              size: 20,
              color: _isSuccess
                  ? Colors.green
                  : (widget.color ?? Colors.grey[700]),
            ),
          ),
          tooltip: widget.tooltip,
          onPressed: _handlePress,
          splashRadius: 20,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
