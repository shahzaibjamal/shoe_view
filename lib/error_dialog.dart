import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDismissed;

  const ErrorDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.onDismissed,
  }) : super(key: key);

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
      content: Text(message),
      actions: [
        TextButton(
          child: Text('OK'),
          onPressed: () {
            Navigator.of(context).pop();
            onDismissed();
            },
        ),
      ],
    );
  }
}
