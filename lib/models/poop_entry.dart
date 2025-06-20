// Import the enums from Session model since they're shared
import 'session.dart';

class PoopEntry {
  final int? id;
  final int sessionId;
  final PoopAmount amount;
  final PoopConsistency consistency;
  final PoopColor color;
  final DateTime time;
  final String? photoPath;
  final bool hasPhoto;

  const PoopEntry({
    this.id,
    required this.sessionId,
    required this.amount,
    required this.consistency,
    required this.color,
    required this.time,
    this.photoPath,
    this.hasPhoto = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'amount': amount.index,
      'consistency': consistency.index,
      'color': color.index,
      'time': time.toIso8601String(),
      'photo_path': photoPath,
      'has_photo': hasPhoto ? 1 : 0,
    };
  }

  factory PoopEntry.fromMap(Map<String, dynamic> map) {
    return PoopEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      amount: PoopAmount.values[map['amount'] as int],
      consistency: PoopConsistency.values[map['consistency'] as int],
      color: PoopColor.values[map['color'] as int],
      time: DateTime.parse(map['time'] as String),
      photoPath: map['photo_path'] as String?,
      hasPhoto: map['has_photo'] == 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory PoopEntry.fromJson(Map<String, dynamic> json) => PoopEntry.fromMap(json);

  PoopEntry copyWith({
    int? id,
    int? sessionId,
    PoopAmount? amount,
    PoopConsistency? consistency,
    PoopColor? color,
    DateTime? time,
    String? photoPath,
    bool? hasPhoto,
  }) {
    return PoopEntry(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      consistency: consistency ?? this.consistency,
      color: color ?? this.color,
      time: time ?? this.time,
      photoPath: photoPath ?? this.photoPath,
      hasPhoto: hasPhoto ?? this.hasPhoto,
    );
  }
}
