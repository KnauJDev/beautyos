import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ticket_payment.dart' show formatMoney;

class ClientSummary {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final bool active;
  final DateTime? createdAt;
  final double balanceAmount;
  final int totalVisits;
  final double totalSpent;
  final double averageTicket;
  final DateTime? lastVisitAt;
  final DateTime? firstVisitAt;
  final int? daysSinceLastVisit;
  final int? avgDaysBetweenVisits;
  final String segment;

  const ClientSummary({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    this.active = true,
    required this.createdAt,
    this.balanceAmount = 0,
    this.totalVisits = 0,
    this.totalSpent = 0,
    this.averageTicket = 0,
    this.lastVisitAt,
    this.firstVisitAt,
    this.daysSinceLastVisit,
    this.avgDaysBetweenVisits,
    this.segment = 'sin_visitas',
  });

  factory ClientSummary.fromMap(Map<String, dynamic> map) {
    return ClientSummary(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString() ?? 'Sin teléfono',
      email: map['email']?.toString(),
      notes: map['notes']?.toString(),
      active: map['active'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      balanceAmount:
          double.tryParse(map['balance_amount']?.toString() ?? '') ?? 0,
      totalVisits:
          int.tryParse(map['total_visits']?.toString() ?? '') ?? 0,
      totalSpent:
          double.tryParse(map['total_spent']?.toString() ?? '') ?? 0,
      averageTicket:
          double.tryParse(map['average_ticket']?.toString() ?? '') ?? 0,
      lastVisitAt: map['last_visit_at'] == null
          ? null
          : DateTime.tryParse(map['last_visit_at'].toString()),
      firstVisitAt: map['first_visit_at'] == null
          ? null
          : DateTime.tryParse(map['first_visit_at'].toString()),
      daysSinceLastVisit:
          int.tryParse(map['days_since_last_visit']?.toString() ?? ''),
      avgDaysBetweenVisits:
          int.tryParse(map['avg_days_between_visits']?.toString() ?? ''),
      segment: map['segment']?.toString() ?? 'sin_visitas',
    );
  }

  /// Extrae el primer nombre del cliente para saludos personalizados en WhatsApp.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Cliente';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  String get formattedTotalSpent => formatMoney(totalSpent);
  String get formattedAverageTicket => formatMoney(averageTicket);
  String get formattedBalanceAmount => formatMoney(balanceAmount);

  bool get hasPendingBalance => balanceAmount > 0;

  /// Texto legible de cadencia de visita (frecuencia promedio).
  String get cadenceText {
    if (totalVisits == 0) return 'Sin visitas';
    if (totalVisits == 1 || avgDaysBetweenVisits == null) return '1ª visita';
    return 'Cada ~$avgDaysBetweenVisits días';
  }

  /// Texto legible del tiempo transcurrido desde la última atención.
  String get lastVisitText {
    if (daysSinceLastVisit == null) return 'Sin visitas registradas';
    if (daysSinceLastVisit == 0) return 'Hoy';
    if (daysSinceLastVisit == 1) return 'Ayer';
    return 'Hace $daysSinceLastVisit días';
  }

  /// Etiqueta visual del segmento.
  String get segmentLabel {
    switch (segment) {
      case 'vip':
        return '⭐ VIP';
      case 'recurrente':
        return '🟢 Recurrente';
      case 'nuevo':
        return '🆕 Nuevo';
      case 'en_riesgo':
        return '⚠️ En riesgo';
      default:
        return '⚪ Sin visitas';
    }
  }

  /// Color de fondo y borde para el chip de segmento.
  (Color, Color) get segmentColors {
    switch (segment) {
      case 'vip':
        return (AppColors.brandTint, AppColors.brandDark);
      case 'recurrente':
        return (AppColors.stateConfirmedTint, AppColors.stateConfirmed);
      case 'nuevo':
        return (AppColors.stateInProgressTint, AppColors.stateInProgress);
      case 'en_riesgo':
        return (AppColors.stateToCollectTint, AppColors.stateToCollect);
      default:
        return (AppColors.surfaceAlt, AppColors.textSecondary);
    }
  }
}
