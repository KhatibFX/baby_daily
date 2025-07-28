import '../../constants/enum_labels.dart';
import '../../utils/enum_utils.dart';

enum PoopAmount { small, medium, large, blowout }

extension PoopAmountExtension on PoopAmount {
  String get label {
    switch (this) {
      case PoopAmount.small:
        return PoopAmountLabels.small;
      case PoopAmount.medium:
        return PoopAmountLabels.medium;
      case PoopAmount.large:
        return PoopAmountLabels.large;
      case PoopAmount.blowout:
        return PoopAmountLabels.blowout;
    }
  }

  static PoopAmount? fromString(String? value) {
    return EnumUtils.fromString(PoopAmount.values, value);
  }
}

enum PoopConsistency { normal, dry, liquid, diarrhea }

extension PoopConsistencyExtension on PoopConsistency {
  String get label {
    switch (this) {
      case PoopConsistency.normal:
        return PoopConsistencyLabels.normal;
      case PoopConsistency.dry:
        return PoopConsistencyLabels.dry;
      case PoopConsistency.liquid:
        return PoopConsistencyLabels.liquid;
      case PoopConsistency.diarrhea:
        return PoopConsistencyLabels.diarrhea;
    }
  }

  static PoopConsistency? fromString(String? value) {
    return EnumUtils.fromString(PoopConsistency.values, value);
  }
}

enum PoopColor { green, yellow, yellowGreen, abnormal }

extension PoopColorExtension on PoopColor {
  String get label {
    switch (this) {
      case PoopColor.green:
        return PoopColorLabels.green;
      case PoopColor.yellow:
        return PoopColorLabels.yellow;
      case PoopColor.yellowGreen:
        return PoopColorLabels.yellowGreen;
      case PoopColor.abnormal:
        return PoopColorLabels.abnormal;
    }
  }

  static PoopColor? fromString(String? value) {
    return EnumUtils.fromString(PoopColor.values, value);
  }
} 