import 'package:flutter/material.dart';

import '../../models/session.dart';

class VitaminSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const VitaminSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(
              'Vitamin AD',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Spacer(),
            Switch(
              value: session.vitaminAD,
              onChanged: (bool value) {
                final updatedSession = session.copyWith(vitaminAD: value);
                onSessionChanged(updatedSession);
              },
            ),
          ],
        ),
      ),
    );
  }
}
