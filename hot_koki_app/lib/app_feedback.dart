import 'package:flutter/material.dart';

class AppFeedback {
  const AppFeedback._();

  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
  }) => _show(context, success: true, title: title, message: message);

  static Future<void> error(
    BuildContext context, {
    String title = 'Opération impossible',
    required Object message,
  }) => _show(
    context,
    success: false,
    title: title,
    message: message.toString().replaceFirst('Exception: ', ''),
  );

  static Future<void> _show(
    BuildContext context, {
    required bool success,
    required String title,
    required String message,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle_rounded : Icons.error_rounded,
        color: success ? const Color(0xFFC9491E) : Colors.red.shade800,
        size: 58,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('D’accord'),
        ),
      ],
    ),
  );
}
