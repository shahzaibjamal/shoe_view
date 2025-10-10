import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDismissed;
  final VoidCallback? onYesPressed;
  final ValueNotifier<bool>? isLoadingNotifier;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDismissed,
    this.onYesPressed,
    this.isLoadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.close, color: Colors.red),
          SizedBox(width: 16),
          Expanded(
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (isLoadingNotifier != null)
            ValueListenableBuilder<bool>(
              valueListenable: isLoadingNotifier!,
              builder: (context, isLoading, _) {
                return isLoading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: CircularProgressIndicator(),
                      )
                    : SizedBox.shrink();
              },
            ),
        ],
      ),
      actions: onYesPressed == null
          ? [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismissed();
                },
              ),
            ]
          : [
              TextButton(
                child: Text('No'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismissed();
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isLoadingNotifier ?? ValueNotifier(false),
                builder: (context, isLoading, _) {
                  return TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onYesPressed!();
                          },
                    child: isLoading ? Text('Loading...') : Text('Yes'),
                  );
                },
              ),
            ],
    );
  }
}
