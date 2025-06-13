import 'package:flutter/foundation.dart';

import '../models/session.dart';

class EditSessionProvider with ChangeNotifier {
  Session? _editingSession;

  Session? get editingSession => _editingSession;

  void startEditing(Session session) {
    _editingSession = session.copyWith();
    notifyListeners();
  }

  void updateSession(Session updatedSession) {
    _editingSession = updatedSession;
    notifyListeners();
  }

  void resetSession() {
    _editingSession = null;
    notifyListeners();
  }
}
