class SafeMath {
  /// Arrondit à 2 décimales pour éviter les problèmes IEEE 754 (ex: 0.1 + 0.2 = 0.3)
  static double round2(double value) {
    return (value * 100).round() / 100;
  }

  /// Arrondissement dynamique basé sur le nombre de décimales demandées
  static double roundTo(double value, {int decimals = 2}) {
    if (decimals == 0) return value.roundToDouble();
    num mod = 1;
    for (int i = 0; i < decimals; i++) {
        mod *= 10;
    }
    return (value * mod).round() / mod;
  }

  /// S'assure de l'absence de NaN, Infinity ou null, avec un fallback sécurisé
  static double safeDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    
    double numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      numVal = double.tryParse(value) ?? fallback;
    } else {
      numVal = fallback;
    }

    if (numVal.isNaN || numVal.isInfinite) {
      return fallback;
    }
    
    return numVal;
  }
}
