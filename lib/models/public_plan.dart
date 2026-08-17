/// Representa una funcionalidad o capacidad dentro de un plan comercial.
class PublicPlanFeature {
  const PublicPlanFeature({
    required this.key,
    required this.name,
    required this.enabled,
    this.limitValue,
  });

  final String key;
  final String name;
  final bool enabled;
  final int? limitValue;

  bool get isUnlimited => enabled && limitValue == null;

  factory PublicPlanFeature.fromMap(Map<String, dynamic> map) {
    final rawLimit = map['feature_limit'] ?? map['limit_value'];
    int? parsedLimit;
    if (rawLimit != null) {
      parsedLimit = int.tryParse(rawLimit.toString());
    }

    return PublicPlanFeature(
      key: map['feature_key']?.toString() ?? map['key']?.toString() ?? '',
      name: map['feature_name']?.toString() ?? map['name']?.toString() ?? '',
      enabled: map['feature_enabled'] == true || map['enabled'] == true,
      limitValue: parsedLimit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'feature_key': key,
      'feature_name': name,
      'feature_enabled': enabled,
      'feature_limit': limitValue,
    };
  }
}

/// Representa un plan comercial público de Salón y Más (Básico, Business, Profesional).
class PublicPlan {
  const PublicPlan({
    required this.code,
    required this.name,
    required this.billingPeriod,
    required this.priceCop,
    required this.currencyCode,
    required this.features,
  });

  final String code;
  final String name;
  final String billingPeriod;
  final int priceCop;
  final String currencyCode;
  final List<PublicPlanFeature> features;

  /// Devuelve si este plan es el sugerido / más popular (Business).
  bool get isPopular => code.toLowerCase() == 'business';

  /// Devuelve si es el plan de más alto nivel (Profesional).
  bool get isElite => code.toLowerCase() == 'profesional';

  /// Precio formateado en pesos colombianos, ej: "$160.000"
  String get formattedPrice {
    final digits = priceCop.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      buffer.write(digits[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '\$${buffer.toString().split('').reversed.join('')}';
  }

  /// Texto del período de cobro, ej: "mes"
  String get periodLabel {
    switch (billingPeriod.toLowerCase()) {
      case 'yearly':
      case 'anual':
        return 'año';
      case 'monthly':
      case 'mensual':
      default:
        return 'mes';
    }
  }

  /// Resumen del límite de sedes
  String get branchesLabel {
    final feature = featureByKey('branches');
    if (feature == null || !feature.enabled) return 'Sin sedes';
    if (feature.isUnlimited) return 'Sedes ilimitadas';
    if (feature.limitValue == 1) return '1 Sede principal';
    return 'Hasta ${feature.limitValue} sedes';
  }

  /// Resumen del límite de equipo
  String get teamMembersLabel {
    final feature = featureByKey('team_members');
    if (feature == null || !feature.enabled) return 'Sin equipo';
    if (feature.isUnlimited) return 'Equipo ilimitado';
    return 'Hasta ${feature.limitValue} cuentas de equipo';
  }

  /// Busca una feature por su clave
  PublicPlanFeature? featureByKey(String key) {
    for (final f in features) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// Verifica si una feature está activa en este plan
  bool hasFeature(String key) {
    final f = featureByKey(key);
    return f != null && f.enabled;
  }

  /// Agrupa las filas planas devueltas por la RPC `list_public_plans()`
  /// en una lista estructurada de [PublicPlan].
  static List<PublicPlan> fromRows(List<dynamic> rows) {
    final Map<String, _PlanAccumulator> map = {};

    for (final raw in rows) {
      final item = Map<String, dynamic>.from(raw as Map);
      final code = item['plan_code']?.toString() ?? item['code']?.toString() ?? '';
      if (code.isEmpty) continue;

      final acc = map.putIfAbsent(
        code,
        () => _PlanAccumulator(
          code: code,
          name: item['plan_name']?.toString() ?? item['name']?.toString() ?? code,
          billingPeriod: item['billing_period']?.toString() ?? 'monthly',
          priceCop: int.tryParse(item['price_cop']?.toString() ?? '0') ?? 0,
          currencyCode: item['currency_code']?.toString() ?? 'COP',
        ),
      );

      final featureKey = item['feature_key']?.toString();
      if (featureKey != null && featureKey.isNotEmpty) {
        acc.features.add(PublicPlanFeature.fromMap(item));
      }
    }

    // Orden estándar: Básico, Business, Profesional
    final order = ['basico', 'business', 'profesional'];
    final list = map.values.map((a) => a.toPublicPlan()).toList();

    list.sort((a, b) {
      final indexA = order.indexOf(a.code.toLowerCase());
      final indexB = order.indexOf(b.code.toLowerCase());
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      return a.priceCop.compareTo(b.priceCop);
    });

    return list;
  }
}

class _PlanAccumulator {
  _PlanAccumulator({
    required this.code,
    required this.name,
    required this.billingPeriod,
    required this.priceCop,
    required this.currencyCode,
  });

  final String code;
  final String name;
  final String billingPeriod;
  final int priceCop;
  final String currencyCode;
  final List<PublicPlanFeature> features = [];

  PublicPlan toPublicPlan() {
    return PublicPlan(
      code: code,
      name: name,
      billingPeriod: billingPeriod,
      priceCop: priceCop,
      currencyCode: currencyCode,
      features: features,
    );
  }
}
