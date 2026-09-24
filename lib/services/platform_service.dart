import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_subscription.dart';
import '../models/platform_partner.dart';
import '../models/platform_saas_metrics.dart';
import '../models/platform_tenant_feature_override.dart';
import '../models/platform_tenant_summary.dart';
import '../models/tenant_subscription_history_entry.dart';
import 'sesion_supabase.dart';

class PlatformService {
  const PlatformService();

  Future<String?> getMyPlatformRole() async {
    final response = await Supabase.instance.client.rpc('get_my_platform_role');
    return response as String?;
  }

  Future<List<PlatformTenantSummary>> listTenants() async {
    final response = await Supabase.instance.client.rpc(
      'platform_list_tenants',
    );

    return (response as List)
        .map(
          (item) => PlatformTenantSummary.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Aprueba un negocio y, si se negocia un precio, **lo pacta en su sede
  /// principal** (hallazgo AG): desde D-239 quien cobra es la sede.
  ///
  /// **El descuento porcentual ya no se manda.** No es que sobre: el servidor
  /// lo rechaza. El precio de una sede se pacta en pesos, y convertir un
  /// porcentaje perdería su significado — un descuento sigue a la tarifa
  /// cuando la tarifa cambia, un precio pactado no.
  ///
  /// El plan por defecto era `'profesional'`, **jubilado por D-188**, y la
  /// RPC exige un plan activo: cualquier llamada que no pasara uno explícito
  /// habría fallado.
  Future<void> approveTenant({
    required String tenantId,
    String planCode = 'pro',
    bool isFounder = false,
    int? priceCop,
    String? priceReason,
    int trialDays = 21,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_approve_tenant',
      params: {
        'p_tenant_id': tenantId,
        'p_plan_code': planCode,
        'p_is_founder': isFounder,
        'p_price_cop': priceCop,
        'p_price_reason': priceReason,
        'p_trial_days': trialDays,
      },
    );
  }

  Future<void> rejectTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_reject_tenant',
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
    );
  }

  Future<void> suspendTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_suspend_tenant',
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
    );
  }

  Future<void> reactivateTenant({
    required String tenantId,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_reactivate_tenant',
      params: {'p_tenant_id': tenantId, 'p_reason': reason},
    );
  }

  Future<void> extendTrial({
    required String tenantId,
    required DateTime newTrialEndsAt,
    required String reason,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_extend_trial',
      params: {
        'p_tenant_id': tenantId,
        'p_new_trial_ends_at': newTrialEndsAt.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  /// Cambia **el plan y la etiqueta de pionero** de un negocio.
  ///
  /// **Ya no cambia el precio** (hallazgo AG). El precio vive en cada sede y
  /// se pacta con [setBranchSubscription]. Los parámetros de precio y
  /// descuento salieron de aquí a propósito: dejarlos habría permitido mandar
  /// algo que el servidor rechaza, y la pantalla no debe ofrecer lo que la
  /// base niega (D-012, D-095).
  Future<void> updateTenantPricing({
    required String tenantId,
    required String planCode,
    required bool isFounder,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_tenant_pricing',
      params: {
        'p_tenant_id': tenantId,
        'p_plan_code': planCode,
        'p_is_founder': isFounder,
      },
    );
  }

  /// Marca o desmarca un negocio como de ensayo (D-225, paso 9.29).
  ///
  /// Un negocio marcado sale de las metricas del SaaS y deja de recibir los
  /// avisos de vencimiento. Es reversible a proposito: para probar esos
  /// correos hay que poder desmarcarlo, probar, y volver a marcarlo.
  ///
  /// La RPC comprueba por dentro que quien llama sea el dueno de plataforma.
  Future<void> setTenantDemo({
    required String tenantId,
    required bool isDemo,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_tenant_demo',
      params: {'p_tenant_id': tenantId, 'p_is_demo': isDemo},
    );
  }

  /// Cambia el estado de pago de UNA sede (D-236, paso 9.36).
  ///
  /// La RPC existe desde D-190 y no la llamaba nadie: se podia escribir el
  /// estado de una sede desde la base, pero no habia puerta en el Panel.
  ///
  /// Valida por dentro que quien llama sea dueno de plataforma, que el estado
  /// sea uno de los siete validos, y que **un precio pactado traiga motivo**
  /// (mismo criterio que D-136). Aqui no se repite ninguna de las tres: si se
  /// duplicaran, acabarian diciendo cosas distintas.
  Future<void> setBranchSubscription({
    required String branchId,
    required String status,
    int? priceCop,
    String? priceReason,
    DateTime? periodEnd,
    /// Devuelve la sede a la tarifa vigente del plan (D-237).
    ///
    /// Hace falta un parametro explicito porque mandar `priceCop: null` NO
    /// borra el precio: la RPC lo conserva. Sin esto, D-222 prometia algo
    /// que no se podia hacer.
    bool limpiarPrecio = false,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_branch_subscription',
      params: {
        'p_branch_id': branchId,
        'p_status': status,
        'p_price_cop': priceCop,
        'p_price_reason': priceReason,
        'p_period_end': periodEnd?.toUtc().toIso8601String(),
        'p_limpiar_precio': limpiarPrecio,
      },
    );
  }

  /// Borra un negocio de PRUEBA y todo lo suyo (D-246, paso 9.47).
  ///
  /// **La unica llamada del proyecto que destruye datos y no se deshace.**
  /// Las demas escriben, cambian o marcan; esta borra.
  ///
  /// El seguro no esta aqui sino en el servidor: la RPC **se niega si el
  /// negocio no tiene `is_demo = true`**. Se hace alli a proposito -- una
  /// comprobacion en la pantalla la salta cualquiera que llame a la RPC por su
  /// cuenta, y lo que separa "limpio mis pruebas" de "borre a un cliente" no
  /// puede depender de un `if` en Dart.
  ///
  /// Devuelve cuantas filas cayeron en cada tabla, para poder ensenyar lo que
  /// se llevo por delante en vez de un "listo" a secas.
  Future<Map<String, int>> deleteDemoTenant(String tenantId) async {
    final respuesta = await Supabase.instance.client.rpc(
      'platform_delete_demo_tenant',
      params: {'p_tenant_id': tenantId},
    );

    final borrado = <String, int>{};
    if (respuesta is List) {
      for (final fila in respuesta) {
        final mapa = Map<String, dynamic>.from(fila as Map);
        final tabla = mapa['tabla']?.toString() ?? '';
        final filas =
            int.tryParse(mapa['filas_borradas']?.toString() ?? '') ?? 0;
        if (tabla.isNotEmpty) borrado[tabla] = filas;
      }
    }
    return borrado;
  }

  /// Borra los archivos de Storage de un negocio de PRUEBA — fotos de
  /// trabajo, logo, portada y fotos de estilistas — ANTES de llamar a
  /// [deleteDemoTenant], y devuelve el equipo del negocio para poder limpiar
  /// sus cuentas huerfanas DESPUES con [deleteOrphanedAccounts] (hallazgo
  /// AS).
  ///
  /// **El orden importa y no es intercambiable**, mismo criterio que ya usa
  /// `WorkPhotosService.setPortfolioApproval` para retirar una foto: el
  /// archivo se borra antes que la fila que lo referencia. Si esto falla,
  /// no se ha tocado ninguna tabla — el negocio sigue existiendo intacto y
  /// es seguro reintentar.
  ///
  /// El seguro (solo negocios `is_demo = true`) no vive en Flutter: la
  /// funcion de servidor lo vuelve a comprobar por su cuenta, sin fiarse de
  /// esta pantalla.
  Future<({Map<String, int> eliminados, List<String> equipoUserIds})>
  deleteTenantStorageFiles(String tenantId) async {
    final respuesta = await Supabase.instance.client.functions.invoke(
      'platform-delete-tenant-storage',
      headers: await cabecerasParaEdgeFunction(),
      body: {'tenantId': tenantId},
    );

    final datos = Map<String, dynamic>.from(respuesta.data as Map);
    final eliminados = Map<String, dynamic>.from(
      datos['eliminados'] as Map? ?? {},
    ).map((bucket, cantidad) => MapEntry(bucket, (cantidad as num).toInt()));
    final equipoUserIds = (datos['equipoUserIds'] as List? ?? [])
        .map((id) => id.toString())
        .toList();

    return (eliminados: eliminados, equipoUserIds: equipoUserIds);
  }

  /// Borra de Supabase Auth las cuentas de [userIds] que se hayan quedado
  /// sin NINGUN negocio, DESPUES de que [deleteDemoTenant] borró sus filas
  /// (hallazgo AS, segunda mitad).
  ///
  /// **El orden no es opcional:** `tenant_memberships.user_id` es `on
  /// delete restrict` contra `auth.users` -- mientras la fila de membresía
  /// exista, Postgres se niega a borrar la cuenta. Por eso esto se llama
  /// DESPUES de [deleteDemoTenant], nunca antes.
  ///
  /// Los dos seguros (solo cuentas sin ningun otro negocio; nunca un
  /// operador de plataforma) no viven en Flutter: la funcion de servidor
  /// los vuelve a comprobar por su cuenta.
  Future<int> deleteOrphanedAccounts(List<String> userIds) async {
    if (userIds.isEmpty) return 0;

    final respuesta = await Supabase.instance.client.functions.invoke(
      'platform-delete-orphaned-accounts',
      headers: await cabecerasParaEdgeFunction(),
      body: {'userIds': userIds},
    );

    final datos = Map<String, dynamic>.from(respuesta.data as Map);
    return (datos['cuentasBorradas'] as List? ?? []).length;
  }

  /// Escribe los datos propios de UNA sede (D-241, paso 9.42).
  ///
  /// **Todos los parametros son obligatorios y se escriben siempre.** No hay
  /// "manda solo lo que cambia": la RPC no conserva nada, escribe los siete
  /// campos tal cual lleguen, y vacio significa vacio.
  ///
  /// Es a proposito y viene de D-237, donde `coalesce(p_price_cop, price_cop)`
  /// hacia que `null` conservara: la funcion sabia poner y cambiar pero nunca
  /// quitar, y nadie lo noto hasta que el propietario intento borrar un precio.
  /// Al no haber valores por defecto **tampoco se puede llamar a medias y
  /// borrar sin querer los campos que no se mencionaron**.
  ///
  /// Quien la llame debe mandar el formulario entero, que es justo lo que hace
  /// el dialogo del Panel.
  Future<void> updateBranchInfo({
    required String branchId,
    required String? managerName,
    required String? contactEmail,
    required String? contactPhone,
    required String? whatsapp,
    required String? address,
    required String? city,
    required String? department,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_branch_info',
      params: {
        'p_branch_id': branchId,
        'p_manager_name': managerName,
        'p_contact_email': contactEmail,
        'p_contact_phone': contactPhone,
        'p_whatsapp': whatsapp,
        'p_address': address,
        'p_city': city,
        'p_department': department,
      },
    );
  }

  /// El estado de pago de cada sede de un negocio (D-235, paso 9.35).
  ///
  /// Hermana de `get_branch_subscriptions()`, que hace lo mismo pero para el
  /// propio salon. Aquella saca el negocio de `get_my_tenant_id()`; esta lo
  /// recibe, porque el dueno de plataforma mira negocios ajenos.
  ///
  /// Devuelve el mismo `BranchSubscription` a proposito: si el panel y la
  /// pantalla del salon usaran modelos distintos, "al dia" acabaria
  /// significando cosas distintas en cada lado.
  Future<List<BranchSubscription>> getTenantBranches(String tenantId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_branches',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (item) => BranchSubscription.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TenantSubscriptionHistoryEntry>> getTenantSubscriptionHistory(
    String tenantId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_subscription_history',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (item) => TenantSubscriptionHistoryEntry.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> updateTenantContact({
    required String tenantId,
    required String contactName,
    required String contactEmail,
    String? whatsapp,
    String? businessType,
    String? city,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_tenant_contact',
      params: {
        'p_tenant_id': tenantId,
        'p_contact_name': contactName,
        'p_contact_email': contactEmail,
        'p_whatsapp': whatsapp,
        'p_business_type': businessType,
        'p_city': city,
      },
    );
  }

  Future<PlatformSaasMetrics> getSaasMetrics() async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_saas_metrics',
    );
    return PlatformSaasMetrics.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<PlatformTenantFeatureOverride>> getTenantFeatureOverrides(
    String tenantId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_tenant_feature_overrides',
      params: {'p_tenant_id': tenantId},
    );
    return (response as List)
        .map(
          (item) => PlatformTenantFeatureOverride.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> setTenantFeatureOverride({
    required String tenantId,
    required String featureKey,
    required bool enabled,
    int? limitValue,
    required String reason,
    DateTime? endsAt,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_tenant_feature_override',
      params: {
        'p_tenant_id': tenantId,
        'p_feature_key': featureKey,
        'p_enabled': enabled,
        'p_limit_value': limitValue,
        'p_reason': reason,
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteTenantFeatureOverride(String overrideId) async {
    await Supabase.instance.client.rpc(
      'platform_delete_tenant_feature_override',
      params: {'p_override_id': overrideId},
    );
  }

  Future<PlatformPartnersSummary> getPartnersSummary() async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_partners_summary',
    );
    return PlatformPartnersSummary.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<PlatformPartner>> listPartners() async {
    final response = await Supabase.instance.client.rpc(
      'platform_list_partners',
    );
    return (response as List)
        .map(
          (item) =>
              PlatformPartner.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<String> createPartner({
    required String fullName,
    required String referralCode,
    required String payoutChannel,
    required String payoutAccount,
    String? documentId,
    String? phone,
    String? whatsapp,
    String? email,
    String commissionType = 'percentage',
    double commissionValue = 15.0,
    String commissionDuration = 'first_payment_only',
    int? durationMonths,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'platform_create_partner',
      params: {
        'p_full_name': fullName,
        'p_referral_code': referralCode,
        'p_payout_channel': payoutChannel,
        'p_payout_account': payoutAccount,
        'p_document_id': documentId,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_commission_type': commissionType,
        'p_commission_value': commissionValue,
        'p_commission_duration': commissionDuration,
        'p_duration_months': durationMonths,
        'p_notes': notes,
      },
    );
    final rows = response as List;
    return Map<String, dynamic>.from(
      rows.first as Map,
    )['partner_id'].toString();
  }

  Future<void> updatePartner({
    required String partnerId,
    required String fullName,
    String? documentId,
    String? phone,
    String? whatsapp,
    String? email,
    required String payoutChannel,
    required String payoutAccount,
    required String commissionType,
    required double commissionValue,
    required String commissionDuration,
    int? durationMonths,
    required bool active,
    String? notes,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_update_partner',
      params: {
        'p_partner_id': partnerId,
        'p_full_name': fullName,
        'p_document_id': documentId,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_payout_channel': payoutChannel,
        'p_payout_account': payoutAccount,
        'p_commission_type': commissionType,
        'p_commission_value': commissionValue,
        'p_commission_duration': commissionDuration,
        'p_duration_months': durationMonths,
        'p_active': active,
        'p_notes': notes,
      },
    );
  }

  Future<PlatformPartnerDetail> getPartnerDetail(String partnerId) async {
    final response = await Supabase.instance.client.rpc(
      'platform_get_partner_detail',
      params: {'p_partner_id': partnerId},
    );
    return PlatformPartnerDetail.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> setTenantPartner({
    required String tenantId,
    String? partnerId,
  }) async {
    await Supabase.instance.client.rpc(
      'platform_set_tenant_partner',
      params: {'p_tenant_id': tenantId, 'p_partner_id': partnerId},
    );
  }

  Future<PlatformPartnerSettlementResult> settlePartnerCommissions({
    required String partnerId,
    required String payoutMethod,
    String? payoutReference,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'platform_settle_partner_commissions',
      params: {
        'p_partner_id': partnerId,
        'p_payout_method': payoutMethod,
        'p_payout_reference': payoutReference,
        'p_notes': notes,
      },
    );
    final rows = response as List;
    return PlatformPartnerSettlementResult.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
