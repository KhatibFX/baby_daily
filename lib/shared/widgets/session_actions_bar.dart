import 'package:flutter/material.dart';

class SessionActionsBar extends StatelessWidget {
  final bool showCloseButton;
  final VoidCallback? onClose;
  final String? errorMessage;

  const SessionActionsBar({
    super.key,
    this.showCloseButton = true,
    this.onClose,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCloseButton) return SizedBox.shrink();

    return Column(
      children: [
        SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () {
              if (errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage!),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              onClose?.call();
            },
            child: Text('Close Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
