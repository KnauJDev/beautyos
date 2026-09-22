import 'ticket_board.dart' show formatCOP;

class PlatformTenantSummary {
  const PlatformTenantSummary({
    required this.tenantId,
    required this.tenantName,
    this.contactName,
    this.businessType,
    this.city,
    this.estimatedBranches = 1,
    this.estimatedTeamSize = 1,
    this.referralSource,
    this.rejectionReason,
    required this.contactEmail,
    this.contactPhone,
    required this.whatsapp,
    this.instagram,
    this.facebook,
    this.realBranchesCount = 0,
    this.realTeamCount = 0,
    this.teamBreakdown,
    this.branchesBreakdown,
    required this.tenantActive,
    required this.isDemo,
    required this.planCode,
    required this.subscriptionStatus,
    this.isFounder = false,
    this.priceCop,
    this.discountPercent,
    required this.trialEndsAt,
    required this.currentPeriodEnd,
    required this.graceEndsAt,
    required this.createdAt,
    this.paidPeriodsCount = 0,
    this.totalPaidCop = 0,
    this.effectiveMonthlyPrice = 0,
    this.debtStatus,
    this.debtAmountCop = 0,
    this.activeOverridesCount = 0,
    this.partnerId,
    this.partnerName,
    this.referralCodeUsed,
  });

  final String tenantId;
  final String tenantName;

  /// Nombre real del titular (user_profiles.full_name del owner). Null si el
  /// negocio todavía no tiene un owner con perfil activo.
  final String? contactName;
  final String? businessType;
  final String? city;
  final int estimatedBranches;
  final int estimatedTeamSize;
  final String? referralSource;
  final String? rejectionReason;
  final String contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? instagram;
  final String? facebook;

  /// Sedes activas contadas en vivo desde `branches` (D-162), no lo que el
  /// negocio declaró al registrarse (`estimatedBranches`).
  final int realBranchesCount;

  /// Equipo activo contado en vivo desde `user_profiles` (D-162), no lo
  /// declarado al registrarse (`estimatedTeamSize`).
  final int realTeamCount;

  /// Desglose por rol ya formateado por la RPC, ej. "1 dueño, 2 admins, 3
  /// estilistas". Null solo si la RPC vieja todavía no lo envía.
  final String? teamBreakdown;

  /// En que estado de pago estan sus sedes: "1 al dia · 1 en prueba" (D-244).
  ///
  /// Lo arma el servidor, igual que [teamBreakdown] (D-162). **No son numeros
  /// sueltos a proposito:** si la pantalla los recompusiera, el dia que aparezca
  /// un estado nuevo seguiria contando los de siempre y no se enteraria nadie.
  ///
  /// Hace falta desde D-239, que mudo el cobro del negocio a la sede: hasta
  /// entonces un cliente con dos sedes y una en mora se veia exactamente igual
  /// que uno con las dos al dia -- un "2" identico.
  final String? branchesBreakdown;

  final bool tenantActive;

  /// Negocio de prueba del propietario de la plataforma, no un cliente
  /// real (D-112). Es una etiqueta: no restringe nada, solo evita que se
  /// cuente como cliente al mirar cualquier cifra.
  final bool isDemo;
  final String? planCode;
  final String? subscriptionStatus;
  final bool isFounder;
  final int? priceCop;
  final double? discountPercent;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? graceEndsAt;
  final DateTime? createdAt;

  /// Conteo de eventos de ePayco que sí activaron/renovaron la suscripción
  /// (D-172): visión 360° financiera, paso 7.1.
  final int paidPeriodsCount;

  /// LTV: total histórico cobrado a este salón, en COP (D-172).
  final int totalPaidCop;

  /// Precio mensual del negocio, calculado con
  /// `private.beautyos_precio_efectivo` en el servidor (D-172).
  ///
  /// **Es el único que vale, y desde el hallazgo AG es el único que hay.**
  /// Hasta el 22-sep convivía con un `effectivePriceCop` que recalculaba el
  /// precio aquí, y el comentario de esta misma línea ya lo confesaba —
  /// decía que aquel era *"una aproximación cliente"* — mientras la pantalla
  /// pintaba la aproximación y no esto.
  ///
  /// Lo que aquella cuenta tenía dentro: los precios de `basico`, `business`
  /// y `profesional`, **tres planes que D-188 jubiló** y que la base marca
  /// `retired`; y un `isFounder → × 0.5` que es **el 50% del pionero que
  /// D-221 borró del servidor**, y para el que existe el control 207. Se
  /// quitó de la base y se quedó aquí.
  ///
  /// Además el servidor **acumula** precio pactado y descuento (control 207,
  /// comprobación 6), y aquella cuenta devolvía el pactado saltándose el
  /// descuento: el panel podía enseñar más de lo que se cobraba.
  ///
  /// Es la misma corrección de **D-193**, palabra por palabra: *"no fue
  /// actualizar las cifras: fue quitarlas del cliente, porque esa cuenta vive
  /// en el servidor"*.
  final int effectiveMonthlyPrice;

  /// 'al_dia', 'en_prueba' o 'en_mora' (D-172).
  final String? debtStatus;

  /// Monto adeudado en COP si [debtStatus] es 'en_mora'; cero en cualquier
  /// otro caso (D-172).
  final int debtAmountCop;

  /// Excepciones de límites vigentes ahora mismo (D-172, `tenant_feature_
  /// overrides`).
  final int activeOverridesCount;

  /// Partner vinculado a este salón (D-173). Nulo = sin partner.
  final String? partnerId;
  final String? partnerName;

  /// El código de referido tal como se usó al registrarse -- puede no
  /// resolver a ningún [partnerId] si el código no existía en ese momento.
  final String? referralCodeUsed;

  bool get isInDebt => debtStatus == 'en_mora';

  bool get isPending => subscriptionStatus == 'pending';
  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isTrialExpired =>
      isTrialing && trialEndsAt != null && trialEndsAt!.isBefore(DateTime.now());
  bool get isTrialActive =>
      isTrialing && (trialEndsAt == null || trialEndsAt!.isAfter(DateTime.now()));
  bool get isActive => subscriptionStatus == 'active';
  bool get isRejected => subscriptionStatus == 'rejected';
  bool get isGrace => subscriptionStatus == 'grace';
  bool get isPastDue => subscriptionStatus == 'past_due';
  bool get isSuspended => subscriptionStatus == 'suspended';
  bool get isCancelled => subscriptionStatus == 'cancelled';

  String get planNameFormatted {
    switch (planCode?.toLowerCase()) {
      case 'pro':
        return 'Todo Incluido';
      case 'basico':
        return 'Básico';
      case 'business':
        return 'Business';
      case 'profesional':
        return 'Profesional';
      default:
        return planCode ?? 'Todo Incluido';
    }
  }

  /// "Registrado hace 18 días" / "Registrado hace 3 meses" (D-172, paso 7.1).
  String get ageLabel {
    if (createdAt == null) return 'Fecha de registro desconocida';
    final days = DateTime.now().difference(createdAt!).inDays;
    if (days < 1) return 'Registrado hoy';
    if (days < 30) return 'Registrado hace $days ${days == 1 ? "día" : "días"}';
    final months = (days / 30).floor();
    if (months < 12) {
      return 'Registrado hace $months ${months == 1 ? "mes" : "meses"}';
    }
    final years = (months / 12).floor();
    return 'Registrado hace $years ${years == 1 ? "año" : "años"}';
  }

  String get formattedTotalPaid => '${formatCOP(totalPaidCop)} COP';

  String get formattedDebtAmount => '${formatCOP(debtAmountCop)} COP';

  /// Lo que el servidor dice que vale este negocio al mes. **Aquí no se
  /// calcula nada** (AG): ver [effectiveMonthlyPrice].
  int get effectivePriceCop => effectiveMonthlyPrice;

  /// Si ese precio es **un acuerdo** o simplemente la tarifa del plan.
  ///
  /// Mismo criterio que `BranchSubscription.tienePrecioPactado` (D-237): no se
  /// deduce comparando el texto del motivo, porque una cadena pensada para
  /// leerse no decide sobre dinero.
  bool get tieneAcuerdo =>
      (priceCop != null && priceCop! > 0) ||
      (discountPercent != null && discountPercent! > 0);

  String get formattedEffectivePrice {
    final price = effectivePriceCop;
    final digits = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final pos = digits.length - i;
      buffer.write(digits[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write('.');
      }
    }
    return '\$$buffer COP/mes';
  }

  factory PlatformTenantSummary.fromMap(Map<String, dynamic> map) {
    return PlatformTenantSummary(
      tenantId: map['tenant_id'].toString(),
      tenantName: map['tenant_name']?.toString() ?? 'Sin nombre',
      contactName: map['contact_name']?.toString(),
      businessType: map['business_type']?.toString(),
      city: map['city']?.toString(),
      estimatedBranches: _parseInt(map['estimated_branches']) ?? 1,
      estimatedTeamSize: _parseInt(map['estimated_team_size']) ?? 1,
      referralSource: map['referral_source']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      contactEmail: map['contact_email']?.toString() ?? '',
      contactPhone: map['contact_phone']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      instagram: map['instagram']?.toString(),
      facebook: map['facebook']?.toString(),
      realBranchesCount: _parseInt(map['real_branches_count']) ?? 0,
      realTeamCount: _parseInt(map['real_team_count']) ?? 0,
      teamBreakdown: map['team_breakdown']?.toString(),
      branchesBreakdown: map['branches_breakdown']?.toString(),
      tenantActive: map['tenant_active'] == true,
      isDemo: map['is_demo'] == true,
      planCode: map['plan_code']?.toString(),
      subscriptionStatus: map['subscription_status']?.toString(),
      isFounder: map['is_founder'] == true,
      priceCop: _parseInt(map['price_cop']),
      discountPercent: _parseDouble(map['discount_percent']),
      trialEndsAt: _parseDate(map['trial_ends_at']),
      currentPeriodEnd: _parseDate(map['current_period_end']),
      graceEndsAt: _parseDate(map['grace_ends_at']),
      createdAt: _parseDate(map['created_at']),
      paidPeriodsCount: _parseInt(map['paid_periods_count']) ?? 0,
      totalPaidCop: _parseInt(map['total_paid_cop']) ?? 0,
      effectiveMonthlyPrice: _parseInt(map['effective_monthly_price']) ?? 0,
      debtStatus: map['debt_status']?.toString(),
      debtAmountCop: _parseInt(map['debt_amount_cop']) ?? 0,
      activeOverridesCount: _parseInt(map['active_overrides_count']) ?? 0,
      partnerId: map['partner_id']?.toString(),
      partnerName: map['partner_name']?.toString(),
      referralCodeUsed: map['referral_code_used']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
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
