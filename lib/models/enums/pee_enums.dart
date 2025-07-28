import '../../constants/enum_labels.dart';
import '../../utils/enum_utils.dart';

enum PeeAmount { small, medium, large, xlarge }

extension PeeAmountExtension on PeeAmount {
  String get label {
    switch (this) {
      case PeeAmount.small:
        return PeeAmountLabels.small;
      case PeeAmount.medium:
        return PeeAmountLabels.medium;
      case PeeAmount.large:
        return PeeAmountLabels.large;
      case PeeAmount.xlarge:
        return PeeAmountLabels.xlarge;
    }
  }

  static PeeAmount? fromString(String? value) {
    return EnumUtils.fromString(PeeAmount.values, value);
  }
} 