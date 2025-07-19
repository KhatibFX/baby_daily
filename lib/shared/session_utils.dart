import 'package:flutter/material.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';

/// Shows an error snackbar with the given validation message
void showTimeValidationError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}

/// Validates wake-up time against session rules
Future<bool> isValidWakeUpTime(
  BuildContext context,
  DateTime time,
  Session session,
  SessionProvider provider,
) async {
  final previousSession = await provider.getPreviousSession(session);

  // Rule 1: Can't be before previous session's sleep time
  if (previousSession?.sleepTime != null) {
    if (time.isBefore(previousSession!.sleepTime!)) {
      showTimeValidationError(
          context, 'Wake-up time cannot be before previous session\'s sleep time');
      return false;
    }
  }

  // Rule 2: Can't be after any activity time in the current session
  for (final pee in session.peeEntries) {
    if (time.isAfter(pee.time)) {
      showTimeValidationError(context, 'Wake-up time cannot be after any pee time');
      return false;
    }
  }

  for (final poop in session.poopEntries) {
    if (time.isAfter(poop.time)) {
      showTimeValidationError(context, 'Wake-up time cannot be after any poop time');
      return false;
    }
  }

  for (final milk in session.milkEntries) {
    if (time.isAfter(milk.time)) {
      showTimeValidationError(context, 'Wake-up time cannot be after any milk time');
      return false;
    }
  }

  for (final vitamin in session.vitaminEntries) {
    if (time.isAfter(vitamin.time)) {
      showTimeValidationError(context, 'Wake-up time cannot be after any vitamin time');
      return false;
    }
  }

  // Rule 3: Can't be after current session's sleep time (if set)
  if (session.sleepTime != null && time.isAfter(session.sleepTime!)) {
    showTimeValidationError(context, 'Wake-up time cannot be after the session\'s sleep time');
    return false;
  }

  if (time.isAfter(DateTime.now())) {
    showTimeValidationError(context, 'Wake-up time cannot be in the future');
    return false;
  }

  return true;
}

/// Validates sleep time against session rules
Future<bool> isValidSleepTime({
  required BuildContext context,
  required DateTime time,
  required Session session,
  required SessionProvider provider,
}) async {
  // Rule 1: Can't be before current session's wake-up time
  if (time.isBefore(session.wakeUpTime)) {
    showTimeValidationError(context, 'Sleep time cannot be before the session\'s wake-up time');
    return false;
  }

  // Rule 2: Can't be before any activity time
  for (final pee in session.peeEntries) {
    if (time.isBefore(pee.time)) {
      showTimeValidationError(context, 'Sleep time cannot be before any pee time');
      return false;
    }
  }

  for (final poop in session.poopEntries) {
    if (time.isBefore(poop.time)) {
      showTimeValidationError(context, 'Sleep time cannot be before any poop time');
      return false;
    }
  }

  for (final milk in session.milkEntries) {
    if (time.isBefore(milk.time)) {
      showTimeValidationError(context, 'Sleep time cannot be before any milk time');
      return false;
    }
  }

  for (final vitamin in session.vitaminEntries) {
    if (time.isBefore(vitamin.time)) {
      showTimeValidationError(context, 'Sleep time cannot be before any vitamin time');
      return false;
    }
  }

  // Rule 3: Can't be after next session's wake-up time or now
  final nextSession = await provider.getNextSession(session);
  if (nextSession != null && time.isAfter(nextSession.wakeUpTime)) {
    showTimeValidationError(context, 'Sleep time cannot be after next session\'s wake-up time');
    return false;
  }

  if (time.isAfter(DateTime.now())) {
    showTimeValidationError(context, 'Sleep time cannot be in the future');
    return false;
  }

  return true;
}

/// Validates activity time (pee, poop, milk) against session rules
Future<bool> isValidActivityTime({
  required BuildContext context,
  required DateTime time,
  required Session session,
  bool showError = true,
}) async {
  // Rule 1: Can't be before wake-up time
  if (time.isBefore(session.wakeUpTime)) {
    if (showError) {
      showTimeValidationError(context, 'Time cannot be before the session\'s wake-up time');
    }
    return false;
  }

  // Rule 2: Can't be after sleep time if set
  if (session.sleepTime != null && time.isAfter(session.sleepTime!)) {
    if (showError) {
      showTimeValidationError(context, 'Time cannot be after the session\'s sleep time');
    }
    return false;
  }

  // Rule 3: Can't be in the future
  if (time.isAfter(DateTime.now())) {
    if (showError) {
      showTimeValidationError(context, 'Time cannot be in the future');
    }
    return false;
  }

  return true;
}

/// Shows a date picker followed by a time picker.
/// Returns a DateTime if both date and time were selected, null otherwise.
Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (picked != null) {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time != null) {
      return DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    }
  }
  return null;
}

Future<DateTime> getValidEntryTime({
  required BuildContext context,
  required DateTime time,
  required Session session,
}) async {
  if (await isValidActivityTime(context: context, time: time, session: session, showError: false)) {
    return time;
  } else {
    return truncateToMinute(session.wakeUpTime);
  }
}

/// Creates a DateTime with seconds set to 0
DateTime truncateToMinute(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
  );
}
