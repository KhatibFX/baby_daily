import 'enums/pee_enums.dart';

class PeeEntry {
  final int? id;
  final int sessionId;
  final PeeAmount? amount;
  final String? remarks;
  final DateTime time;

  const PeeEntry({
    this.id,
    required this.sessionId,
    this.amount,
    this.remarks,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'amount': amount?.name,
      'remarks': remarks,
      'time': time.toIso8601String(),
    };
  }

  factory PeeEntry.fromMap(Map<String, dynamic> map) {
    return PeeEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      amount: PeeAmountExtension.fromString(map['amount'] as String?),
      remarks: map['remarks'] as String?,
      time: DateTime.parse(map['time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'amount': amount?.name,
      'remarks': remarks,
      'time': time.toIso8601String(),
    };
  }

  factory PeeEntry.fromJson(Map<String, dynamic> json) {
    return PeeEntry(
      id: json['id'] as int?,
      sessionId: json['sessionId'] as int,
      amount: PeeAmountExtension.fromString(json['amount'] as String?),
      remarks: json['remarks'] as String?,
      time: DateTime.parse(json['time'] as String),
    );
  }

  PeeEntry copyWith({
    int? id,
    int? sessionId,
    PeeAmount? amount,
    String? remarks,
    DateTime? time,
  }) {
    return PeeEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      time: time ?? this.time,
    );
  }

  /// Returns true if this entry has all mandatory fields filled
  bool get isComplete => amount != null;
}
