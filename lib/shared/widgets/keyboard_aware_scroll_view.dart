import 'package:flutter/material.dart';

class KeyboardAwareScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: padding,
        // Hide keyboard when scrolling
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    );
  }
}
