class MilkEntry {
  final int? id;
  final int sessionId;
  final int amount;
  final DateTime time;

  const MilkEntry({
    this.id,
    required this.sessionId,
    required this.amount,
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
      amount: map['amount'] as int,
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

  Map<String, dynamic> toJson() => toMap();

  factory MilkEntry.fromJson(Map<String, dynamic> json) => MilkEntry.fromMap(json);
}
