import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_plan.dart';
import 'monitoreo_service.dart';

/// Servicio para consultar los planes públicos comerciales de Salón y Más.
/// Llama a la RPC pública `list_public_plans()` de Supabase (accesible para anon).
/// Si la conexión tarda o falla, reporta el error a MonitoreoService y recurre
/// al catálogo de respaldo (D-124, D-136).
class PublicPlansService {
  const PublicPlansService({this.client});

  final SupabaseClient? client;

  SupabaseClient get _client => client ?? Supabase.instance.client;

  Future<List<PublicPlan>> getPublicPlans() async {
    try {
      final response = await _client.rpc('list_public_plans');
      if (response is List && response.isNotEmpty) {
        final plans = PublicPlan.fromRows(response);
        if (plans.isNotEmpty) {
          return plans;
        }
      }
    } catch (error, stackTrace) {
      // Reportar a MonitoreoService (D-115) para evitar fallos silenciosos
      MonitoreoService.reportarError(
        error,
        stackTrace,
        motivo: 'Fallo al consultar list_public_plans(), usando catalogo de respaldo',
      );
    }

    return fallbackPlans;
  }

  /// Catálogo de respaldo si la RPC no responde (D-188).
  ///
  /// **Un solo plan desde el 01-sep.** La escalera de tres (D-124, D-136) se
  /// retiró: el eje de cobro ya no es qué módulos te dejo usar, sino cuántas
  /// sedes tienes activas. Este respaldo tiene que decir lo mismo que
  /// `list_public_plans()`, o la pantalla mentiría justo cuando falla la red.
  static List<PublicPlan> get fallbackPlans => [
        const PublicPlan(
          code: 'pro',
          name: 'Todo Incluido',
          billingPeriod: 'monthly',
          priceCop: 120000,
          currencyCode: 'COP',
          features: [
            PublicPlanFeature(key: 'branches', name: 'Sedes', enabled: true),
            PublicPlanFeature(
              key: 'team_members',
              name: 'Estilistas y cuentas de equipo',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'agenda_tickets',
              name: 'Agenda digital y tickets de cobro',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'client_records',
              name: 'Ficha de clientes e historial',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'public_booking',
              name: 'Enlace web de reservas sin cuenta',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'inventory',
              name: 'Inventario, compras y gastos',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'financial_reports',
              name: 'Reportes financieros y comisiones',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'portfolio',
              name: 'Fotos de trabajos por estilista',
              enabled: true,
            ),
            PublicPlanFeature(
              key: 'reviews',
              name: 'Reseñas públicas verificadas',
              enabled: true,
            ),
            // Fase 6, sin construir. El Plan Maestro prohibe venderlo antes de
            // que exista, asi que aqui va en false a proposito.
            PublicPlanFeature(
              key: 'social_publishing',
              name: 'Publicación asistida en redes',
              enabled: false,
            ),
          ],
        ),
      ];

  /// Precio pionero por sede (D-188). No es un porcentaje: $80.000 sobre
  /// $120.000 es un 33%, y modelarlo como porcentaje daba $80.004 por
  /// redondeo. Se guarda como precio pactado en la suscripción.
  static const int precioPioneroCop = 80000;
}
