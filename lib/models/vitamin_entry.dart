import 'enums/vitamin_enums.dart';

class VitaminEntry {
  final int? id;
  final int sessionId;
  final DateTime time;
  final VitaminType? type;
  final String? notes;

  const VitaminEntry({
    this.id,
    required this.sessionId,
    required this.time,
    this.type,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'time': time.toIso8601String(),
      'type': type?.name,
      'notes': notes,
    };
  }

  factory VitaminEntry.fromMap(Map<String, dynamic> map) {
    return VitaminEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      time: DateTime.parse(map['time'] as String),
      type: map['type'] != null ? VitaminTypeExtension.fromString(map['type'] as String) : null,
      notes: map['notes'] as String?,
    );
  }

  VitaminEntry copyWith({
    int? id,
    int? sessionId,
    DateTime? time,
    VitaminType? type,
    String? notes,
  }) {
    return VitaminEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      time: time ?? this.time,
      type: type ?? this.type,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'time': time.toIso8601String(),
      'type': type?.name,
      'notes': notes,
    };
  }

  factory VitaminEntry.fromJson(Map<String, dynamic> json) {
    return VitaminEntry(
      id: json['id'] as int?,
      sessionId: json['sessionId'] as int,
      time: DateTime.parse(json['time'] as String),
      type: json['type'] != null ? VitaminTypeExtension.fromString(json['type'] as String) : null,
      notes: json['notes'] as String?,
    );
  }

  /// Returns true if this entry has all mandatory fields filled
  bool get isComplete => type != null;
}
