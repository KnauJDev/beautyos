import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// El estado de un ticket, en un solo sitio (D-107).
///
/// Antes cada pantalla decidia por su cuenta como llamar y como pintar cada
/// estado, y por eso el mismo "finalizado" podia verse de tres maneras. Aqui
/// se define una vez: como se lee, de que color va y a que grupo pertenece.
///
/// Los colores **no cambian con la marca blanca** (D-097): el ambar significa
/// "pendiente" en todos los negocios. Si el estado cambiara de color con cada
/// tema, dejaria de significar algo.
enum TicketStatus {
  solicitado,
  cotizado,
  apartado,
  confirmado,
  enEspera,
  enProceso,
  finalizado,
  cerrado,
  cancelado,
  noAsistio,
  desconocido;

  static TicketStatus desde(String? valor) {
    switch (valor?.toLowerCase().trim()) {
      case 'solicitado':
        return TicketStatus.solicitado;
      case 'cotizado':
        return TicketStatus.cotizado;
      case 'apartado':
        return TicketStatus.apartado;
      case 'confirmado':
        return TicketStatus.confirmado;
      case 'en_espera':
        return TicketStatus.enEspera;
      case 'en_proceso':
        return TicketStatus.enProceso;
      case 'finalizado':
        return TicketStatus.finalizado;
      case 'cerrado':
        return TicketStatus.cerrado;
      case 'cancelado':
        return TicketStatus.cancelado;
      case 'no_asistio':
        return TicketStatus.noAsistio;
      default:
        return TicketStatus.desconocido;
    }
  }

  /// Como se le muestra a una persona.
  String get etiqueta => switch (this) {
    TicketStatus.solicitado => 'Solicitado',
    TicketStatus.cotizado => 'Cotizado',
    TicketStatus.apartado => 'Apartado',
    TicketStatus.confirmado => 'Confirmado',
    TicketStatus.enEspera => 'En espera',
    TicketStatus.enProceso => 'En proceso',
    TicketStatus.finalizado => 'Finalizado',
    TicketStatus.cerrado => 'Cerrado',
    TicketStatus.cancelado => 'Cancelado',
    TicketStatus.noAsistio => 'No asistió',
    TicketStatus.desconocido => 'Sin estado',
  };

  /// Los cinco grupos de la vista de dia del tablero (D-101), agrupados por
  /// **lo que exigen de ti**, no por su nombre tecnico.
  String get grupo => switch (this) {
    TicketStatus.solicitado ||
    TicketStatus.cotizado ||
    TicketStatus.apartado => 'Por confirmar',
    TicketStatus.confirmado || TicketStatus.enEspera => 'Confirmado',
    TicketStatus.enProceso => 'En proceso',
    TicketStatus.finalizado => 'Por cobrar',
    TicketStatus.cerrado => 'Cerrado',
    TicketStatus.cancelado || TicketStatus.noAsistio => 'Sin efecto',
    TicketStatus.desconocido => 'Sin estado',
  };

  Color get color => switch (this) {
    TicketStatus.solicitado ||
    TicketStatus.cotizado ||
    TicketStatus.apartado => AppColors.statePending,
    TicketStatus.confirmado ||
    TicketStatus.enEspera => AppColors.stateConfirmed,
    TicketStatus.enProceso => AppColors.stateInProgress,
    // Coral y no rojo a proposito: si fuera rojo, un dia con muchos cobros
    // pendientes pareceria un desastre cuando es un buen dia de trabajo sin
    // cerrar caja (D-101).
    TicketStatus.finalizado => AppColors.stateToCollect,
    TicketStatus.cerrado => AppColors.stateClosed,
    TicketStatus.cancelado || TicketStatus.noAsistio => AppColors.danger,
    TicketStatus.desconocido => AppColors.textMuted,
  };

  Color get colorSuave => switch (this) {
    TicketStatus.solicitado ||
    TicketStatus.cotizado ||
    TicketStatus.apartado => AppColors.statePendingTint,
    TicketStatus.confirmado ||
    TicketStatus.enEspera => AppColors.stateConfirmedTint,
    TicketStatus.enProceso => AppColors.stateInProgressTint,
    TicketStatus.finalizado => AppColors.stateToCollectTint,
    TicketStatus.cerrado => AppColors.stateClosedTint,
    TicketStatus.cancelado || TicketStatus.noAsistio => AppColors.dangerTint,
    TicketStatus.desconocido => AppColors.surfaceAlt,
  };

  /// Si todavia exige algo del negocio. Es la base de la regla del tablero:
  /// *al cerrar el dia, todo deberia estar en cero salvo "Cerrado"* (D-101).
  bool get requiereAccion => switch (this) {
    TicketStatus.cerrado ||
    TicketStatus.cancelado ||
    TicketStatus.noAsistio ||
    TicketStatus.desconocido => false,
    _ => true,
  };
}

/// Pildora de estado. La forma unica de mostrar en que va un ticket.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.dense = false});

  StatusPill.desde(String? valor, {super.key, this.dense = false})
    : status = TicketStatus.desde(valor);

  final TicketStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: status.colorSuave,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.etiqueta,
        style: TextStyle(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
