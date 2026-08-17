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

  /// Catálogo de respaldo exacto (D-124, D-136) en COP
  static List<PublicPlan> get fallbackPlans => [
        const PublicPlan(
          code: 'basico',
          name: 'Básico',
          billingPeriod: 'monthly',
          priceCop: 160000,
          currencyCode: 'COP',
          features: [
            PublicPlanFeature(key: 'branches', name: 'Sedes', enabled: true, limitValue: 1),
            PublicPlanFeature(key: 'team_members', name: 'Cuentas de equipo', enabled: true, limitValue: 5),
            PublicPlanFeature(key: 'agenda_tickets', name: 'Agenda digital y tickets de cobro', enabled: true),
            PublicPlanFeature(key: 'client_records', name: 'Ficha de clientes e historial', enabled: true),
            PublicPlanFeature(key: 'public_booking', name: 'Enlace web de reservas sin cuenta', enabled: true),
            PublicPlanFeature(key: 'inventory', name: 'Inventario, compras y gastos', enabled: false),
            PublicPlanFeature(key: 'financial_reports', name: 'Reportes financieros avanzados', enabled: false),
            PublicPlanFeature(key: 'portfolio', name: 'Fotos de trabajos por estilista', enabled: false),
            PublicPlanFeature(key: 'reviews', name: 'Reseñas públicas verificadas', enabled: false),
            PublicPlanFeature(key: 'social_publishing', name: 'Herramientas de IA y publicación social', enabled: false),
          ],
        ),
        const PublicPlan(
          code: 'business',
          name: 'Business',
          billingPeriod: 'monthly',
          priceCop: 200000,
          currencyCode: 'COP',
          features: [
            PublicPlanFeature(key: 'branches', name: 'Sedes', enabled: true, limitValue: 3),
            PublicPlanFeature(key: 'team_members', name: 'Cuentas de equipo', enabled: true, limitValue: 15),
            PublicPlanFeature(key: 'agenda_tickets', name: 'Agenda digital y tickets de cobro', enabled: true),
            PublicPlanFeature(key: 'client_records', name: 'Ficha de clientes e historial', enabled: true),
            PublicPlanFeature(key: 'public_booking', name: 'Enlace web de reservas sin cuenta', enabled: true),
            PublicPlanFeature(key: 'inventory', name: 'Inventario, compras y gastos', enabled: true),
            PublicPlanFeature(key: 'financial_reports', name: 'Reportes financieros avanzados', enabled: true),
            PublicPlanFeature(key: 'portfolio', name: 'Fotos de trabajos por estilista', enabled: false),
            PublicPlanFeature(key: 'reviews', name: 'Reseñas públicas verificadas', enabled: false),
            PublicPlanFeature(key: 'social_publishing', name: 'Herramientas de IA y publicación social', enabled: false),
          ],
        ),
        const PublicPlan(
          code: 'profesional',
          name: 'Profesional',
          billingPeriod: 'monthly',
          priceCop: 240000,
          currencyCode: 'COP',
          features: [
            PublicPlanFeature(key: 'branches', name: 'Sedes', enabled: true, limitValue: null),
            PublicPlanFeature(key: 'team_members', name: 'Cuentas de equipo', enabled: true, limitValue: null),
            PublicPlanFeature(key: 'agenda_tickets', name: 'Agenda digital y tickets de cobro', enabled: true),
            PublicPlanFeature(key: 'client_records', name: 'Ficha de clientes e historial', enabled: true),
            PublicPlanFeature(key: 'public_booking', name: 'Enlace web de reservas sin cuenta', enabled: true),
            PublicPlanFeature(key: 'inventory', name: 'Inventario, compras y gastos', enabled: true),
            PublicPlanFeature(key: 'financial_reports', name: 'Reportes financieros avanzados', enabled: true),
            PublicPlanFeature(key: 'portfolio', name: 'Fotos de trabajos por estilista', enabled: true),
            PublicPlanFeature(key: 'reviews', name: 'Reseñas públicas verificadas', enabled: true),
            PublicPlanFeature(key: 'social_publishing', name: 'Herramientas de IA y publicación social', enabled: true),
          ],
        ),
      ];
}
