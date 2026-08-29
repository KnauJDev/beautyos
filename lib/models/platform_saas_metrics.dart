/// Cabecera ejecutiva del Panel de Plataforma (D-172, paso 7.4). Mapea el
/// jsonb que devuelve `public.platform_get_saas_metrics()`.
class PlatformSaasMetrics {
  const PlatformSaasMetrics({
    required this.mrrCop,
    required this.totalCollectedCop,
    required this.activeCount,
    required this.trialingCount,
    required this.pastDueCount,
    required this.cancelledCount,
    required this.conversionRatePercent,
  });

  final int mrrCop;
  final int totalCollectedCop;
  final int activeCount;
  final int trialingCount;
  final int pastDueCount;
  final int cancelledCount;
  final double conversionRatePercent;

  factory PlatformSaasMetrics.fromMap(Map<String, dynamic> map) {
    return PlatformSaasMetrics(
      mrrCop: _parseInt(map['mrr_cop']) ?? 0,
      totalCollectedCop: _parseInt(map['total_collected_cop']) ?? 0,
      activeCount: _parseInt(map['active_count']) ?? 0,
      trialingCount: _parseInt(map['trialing_count']) ?? 0,
      pastDueCount: _parseInt(map['past_due_count']) ?? 0,
      cancelledCount: _parseInt(map['cancelled_count']) ?? 0,
      conversionRatePercent: _parseDouble(map['conversion_rate_percent']) ?? 0,
    );
  }

  static const empty = PlatformSaasMetrics(
    mrrCop: 0,
    totalCollectedCop: 0,
    activeCount: 0,
    trialingCount: 0,
    pastDueCount: 0,
    cancelledCount: 0,
    conversionRatePercent: 0,
  );

  String get formattedMrr => _formatCop(mrrCop);

  String get formattedTotalCollected => _formatCop(totalCollectedCop);

  String get formattedConversionRate =>
      '${conversionRatePercent.toStringAsFixed(1)}%';

  static String _formatCop(int cop) {
    final digits = cop.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final pos = digits.length - i;
      buffer.write(digits[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
