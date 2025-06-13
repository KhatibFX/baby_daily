import 'package:flutter/material.dart';

Future<bool> showDiscardChangesDialog({
  required BuildContext context,
  String title = 'Discard Changes?',
  String message = 'You have unsaved changes. Do you want to discard them?',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Discard'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
    ),
  );
  
  return result ?? false;
}
