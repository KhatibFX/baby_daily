enum VitaminType {
  ad,
  other,
  // Future types can be added here
}

extension VitaminTypeExtension on VitaminType {
  String get label {
    switch (this) {
      case VitaminType.ad:
        return 'AD';
      case VitaminType.other:
        return 'Other';
    }
  }

  static VitaminType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ad':
        return VitaminType.ad;
      case 'other':
        return VitaminType.other;
      default:
        return VitaminType.other;
    }
  }
}

class VitaminEntry {
  final int? id;
  final int sessionId;
  final DateTime time;
  final VitaminType type;
  final String? notes;

  const VitaminEntry({
    this.id,
    required this.sessionId,
    required this.time,
    this.type = VitaminType.ad, // Default to AD
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'time': time.toIso8601String(),
      'type': type.name,
      'notes': notes,
    };
  }

  factory VitaminEntry.fromMap(Map<String, dynamic> map) {
    return VitaminEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      time: DateTime.parse(map['time'] as String),
      type: VitaminTypeExtension.fromString(map['type'] as String),
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

  Map<String, dynamic> toJson() => toMap();

  factory VitaminEntry.fromJson(Map<String, dynamic> json) => VitaminEntry.fromMap(json);
}
