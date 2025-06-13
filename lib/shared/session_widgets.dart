import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'session_utils.dart';

class TimePickerButton extends StatelessWidget {
  final DateTime? time;
  final String label;
  final DateTime firstDate;
  final DateTime lastDate;
  final Future<bool> Function(DateTime) onValidate;
  final Function(DateTime) onTimeSelected;

  const TimePickerButton({
    Key? key,
    required this.time,
    required this.label,
    required this.firstDate,
    required this.lastDate,
    required this.onValidate,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        FocusScope.of(context).unfocus();
        final newDateTime = await showDateTimePicker(
          context: context,
          initialDate: time ?? truncateToMinute(DateTime.now()),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (newDateTime != null && await onValidate(newDateTime)) {
          onTimeSelected(newDateTime);
        }
      },
      child: Text(label),
    );
  }
}

class TimeDisplay extends StatelessWidget {
  final DateTime? time;
  final String placeholder;

  const TimeDisplay({
    Key? key,
    required this.time,
    required this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      time != null ? DateFormat('MMM dd, yyyy HH:mm').format(time!) : placeholder,
    );
  }
}

class NowButton extends StatelessWidget {
  final Future<bool> Function(DateTime) onValidate;
  final Function(DateTime) onTimeSelected;

  const NowButton({
    Key? key,
    required this.onValidate,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        FocusScope.of(context).unfocus();
        final now = truncateToMinute(DateTime.now());
        if (await onValidate(now)) {
          onTimeSelected(now);
        }
      },
      child: Text('Now'),
    );
  }
}

class TimePickerRow extends StatelessWidget {
  final DateTime? time;
  final String placeholder;
  final IconData? icon;
  final DateTime firstDate;
  final DateTime lastDate;
  final Future<bool> Function(DateTime) onValidate;
  final Function(DateTime) onTimeSelected;

  const TimePickerRow({
    Key? key,
    required this.time,
    required this.placeholder,
    this.icon,
    required this.firstDate,
    required this.lastDate,
    required this.onValidate,
    required this.onTimeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) Icon(icon),
        if (icon != null) SizedBox(width: 8),
        TimeDisplay(time: time, placeholder: placeholder),
        Spacer(),
        NowButton(
          onValidate: onValidate,
          onTimeSelected: onTimeSelected,
        ),
        SizedBox(width: 8),
        TimePickerButton(
          time: time,
          label: time == null ? 'Set' : 'Change',
          firstDate: firstDate,
          lastDate: lastDate,
          onValidate: onValidate,
          onTimeSelected: onTimeSelected,
        ),
      ],
    );
  }
}
