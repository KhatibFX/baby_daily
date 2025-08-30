class MilkEntry {
  final int? id;
  final int sessionId;
  final int? amount;
  final DateTime time;

  const MilkEntry({
    this.id,
    required this.sessionId,
    this.amount,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'amount': amount,
      'time': time.toIso8601String(),
    };
  }

  factory MilkEntry.fromMap(Map<String, dynamic> map) {
    return MilkEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      amount: map['amount'] as int?,
      time: DateTime.parse(map['time'] as String),
    );
  }

  MilkEntry copyWith({
    int? id,
    int? sessionId,
    int? amount,
    DateTime? time,
  }) {
    return MilkEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'amount': amount,
      'time': time.toIso8601String(),
    };
  }

  factory MilkEntry.fromJson(Map<String, dynamic> json) {
    return MilkEntry(
      id: json['id'] as int?,
      sessionId: json['sessionId'] as int,
      amount: json['amount'] as int?,
      time: DateTime.parse(json['time'] as String),
    );
  }

  /// Returns true if this entry has all mandatory fields filled
  bool get isComplete => amount != null && amount! > 0;
}
