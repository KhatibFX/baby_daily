import 'package:flutter/foundation.dart';

enum PeeAmount { na, small, medium, large, xlarge }
enum PoopAmount { na, small, medium, large, blowout }
enum PoopConsistency { normal, dry, liquid, diarrhea }
enum PoopColor { green, yellow, yellowGreen, abnormal }

class Session {
  final int? id;
  DateTime wakeUpTime;
  PeeAmount pee;
  String? peeRemarks;
  DateTime? peeTime;  // New field
  PoopAmount poopAmount;
  PoopConsistency poopConsistency;
  PoopColor poopColor;
  DateTime? poopTime;  // New field
  String? abnormalPoopPhotoPath;
  bool hasAbnormalPoopPhoto;
  int milkIntake;
  DateTime? milkTime;  // New field
  bool vitaminAD;
  DateTime? sleepTime;
  String? sessionPhotoPath;
  bool hasSessionPhoto;
  bool isClosed;

  Session({
    this.id,
    required this.wakeUpTime,
    this.pee = PeeAmount.na,
    this.peeRemarks,
    this.peeTime,  // New field
    this.poopAmount = PoopAmount.na,
    this.poopConsistency = PoopConsistency.normal,
    this.poopColor = PoopColor.yellow,
    this.poopTime,  // New field
    this.abnormalPoopPhotoPath,
    this.hasAbnormalPoopPhoto = false,
    this.milkIntake = 0,
    this.milkTime,  // New field
    this.vitaminAD = false,
    this.sleepTime,
    this.sessionPhotoPath,
    this.hasSessionPhoto = false,
    this.isClosed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wakeUpTime': wakeUpTime.toIso8601String(),
      'pee': pee.index,
      'peeRemarks': peeRemarks,
      'peeTime': peeTime?.toIso8601String(),  // New field
      'poopAmount': poopAmount.index,
      'poopConsistency': poopConsistency.index,
      'poopColor': poopColor.index,
      'poopTime': poopTime?.toIso8601String(),  // New field
      'abnormalPoopPhotoPath': abnormalPoopPhotoPath,
      'hasAbnormalPoopPhoto': hasAbnormalPoopPhoto ? 1 : 0,
      'milkIntake': milkIntake,
      'milkTime': milkTime?.toIso8601String(),  // New field
      'vitaminAD': vitaminAD ? 1 : 0,
      'sleepTime': sleepTime?.toIso8601String(),
      'sessionPhotoPath': sessionPhotoPath,
      'hasSessionPhoto': hasSessionPhoto ? 1 : 0,
      'isClosed': isClosed ? 1 : 0,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      wakeUpTime: DateTime.parse(map['wakeUpTime']),
      pee: PeeAmount.values[map['pee']],
      peeRemarks: map['peeRemarks'],
      peeTime: map['peeTime'] != null ? DateTime.parse(map['peeTime']) : null,  // New field
      poopAmount: PoopAmount.values[map['poopAmount']],
      poopConsistency: PoopConsistency.values[map['poopConsistency']],
      poopColor: PoopColor.values[map['poopColor']],
      poopTime: map['poopTime'] != null ? DateTime.parse(map['poopTime']) : null,  // New field
      abnormalPoopPhotoPath: map['abnormalPoopPhotoPath'],
      hasAbnormalPoopPhoto: map['hasAbnormalPoopPhoto'] == 1,
      milkIntake: map['milkIntake'],
      milkTime: map['milkTime'] != null ? DateTime.parse(map['milkTime']) : null,  // New field
      vitaminAD: map['vitaminAD'] == 1,
      sleepTime: map['sleepTime'] != null 
          ? DateTime.parse(map['sleepTime'])
          : null,
      sessionPhotoPath: map['sessionPhotoPath'],
      hasSessionPhoto: map['hasSessionPhoto'] == 1,
      isClosed: map['isClosed'] == 1,
    );
  }

  Session copyWith({
    int? id,
    DateTime? wakeUpTime,
    PeeAmount? pee,
    String? peeRemarks,
    DateTime? peeTime,  // New field
    PoopAmount? poopAmount,
    PoopConsistency? poopConsistency,
    PoopColor? poopColor,
    DateTime? poopTime,  // New field
    String? abnormalPoopPhotoPath,
    bool? hasAbnormalPoopPhoto,
    int? milkIntake,
    DateTime? milkTime,  // New field
    bool? vitaminAD,
    DateTime? sleepTime,
    String? sessionPhotoPath,
    bool? hasSessionPhoto,
    bool? isClosed,
  }) {
    return Session(
      id: id ?? this.id,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      pee: pee ?? this.pee,
      peeRemarks: peeRemarks ?? this.peeRemarks,
      peeTime: peeTime ?? this.peeTime,  // New field
      poopAmount: poopAmount ?? this.poopAmount,
      poopConsistency: poopConsistency ?? this.poopConsistency,
      poopColor: poopColor ?? this.poopColor,
      poopTime: poopTime ?? this.poopTime,  // New field
      abnormalPoopPhotoPath: abnormalPoopPhotoPath ?? this.abnormalPoopPhotoPath,
      hasAbnormalPoopPhoto: hasAbnormalPoopPhoto ?? this.hasAbnormalPoopPhoto,
      milkIntake: milkIntake ?? this.milkIntake,
      milkTime: milkTime ?? this.milkTime,  // New field
      vitaminAD: vitaminAD ?? this.vitaminAD,
      sleepTime: sleepTime ?? this.sleepTime,
      sessionPhotoPath: sessionPhotoPath ?? this.sessionPhotoPath,
      hasSessionPhoto: hasSessionPhoto ?? this.hasSessionPhoto,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
