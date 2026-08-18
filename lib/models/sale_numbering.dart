/// Modelo de configuración de consecutivo de ventas y Resolución DIAN por sede.
///
/// Implementa D-150 / Hallazgo P: separa el número operativo del número contable.
class BranchSaleNumbering {
  final String tenantId;
  final String branchId;
  final String prefix;
  final int nextNumber;
  final int padding;
  final String? resolutionNumber;
  final DateTime? resolutionDate;
  final int? rangeFrom;
  final int? rangeTo;
  final DateTime? validUntil;
  final int lastEmittedNumber;
  final DateTime updatedAt;

  const BranchSaleNumbering({
    required this.tenantId,
    required this.branchId,
    this.prefix = 'VTA-',
    this.nextNumber = 1,
    this.padding = 7,
    this.resolutionNumber,
    this.resolutionDate,
    this.rangeFrom,
    this.rangeTo,
    this.validUntil,
    this.lastEmittedNumber = 0,
    required this.updatedAt,
  });

  /// Muestra el próximo código formateado que se emitirá (ej. 'VTA-0000001' o 'FJ-020000')
  String get previewNextCode {
    return '$prefix${nextNumber.toString().padLeft(padding, '0')}';
  }

  /// Indica si la sede tiene una resolución DIAN formal configurada
  bool get hasResolution =>
      resolutionNumber != null && resolutionNumber!.trim().isNotEmpty;

  /// Indica si la numeración actual está cerca de agotar el rango autorizado DIAN
  bool get isNearLimit {
    if (rangeTo == null) return false;
    final remaining = rangeTo! - nextNumber;
    return remaining <= 100;
  }

  /// Indica si la resolución DIAN está vencida o por vencer (menos de 30 días)
  bool get isExpiringSoon {
    if (validUntil == null) return false;
    final daysRemaining = validUntil!.difference(DateTime.now()).inDays;
    return daysRemaining <= 30;
  }

  factory BranchSaleNumbering.fromJson(Map<String, dynamic> json) {
    return BranchSaleNumbering(
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      prefix: json['prefix']?.toString() ?? 'VTA-',
      nextNumber: int.tryParse(json['next_number']?.toString() ?? '1') ?? 1,
      padding: int.tryParse(json['padding']?.toString() ?? '7') ?? 7,
      resolutionNumber: json['resolution_number']?.toString(),
      resolutionDate: json['resolution_date'] != null
          ? DateTime.tryParse(json['resolution_date'].toString())
          : null,
      rangeFrom: int.tryParse(json['range_from']?.toString() ?? ''),
      rangeTo: int.tryParse(json['range_to']?.toString() ?? ''),
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'].toString())
          : null,
      lastEmittedNumber:
          int.tryParse(json['last_emitted_number']?.toString() ?? '0') ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'p_branch_id': branchId,
      'p_prefix': prefix,
      'p_next_number': nextNumber,
      'p_padding': padding,
      'p_resolution_number': resolutionNumber,
      'p_resolution_date': resolutionDate?.toIso8601String().split('T').first,
      'p_range_from': rangeFrom,
      'p_range_to': rangeTo,
      'p_valid_until': validUntil?.toIso8601String().split('T').first,
    };
  }
}
