import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/platform_partner.dart';
import 'package:salonymas/models/platform_tenant_summary.dart';

Map<String, dynamic> _basePartnerMap() => {
  'partner_id': 'p1',
  'full_name': 'Carlos Pérez',
  'referral_code': 'CARLOS',
  'payout_channel': 'bre_b',
  'payout_account': '3001234567',
  'commission_type': 'percentage',
  'commission_value': 15.0,
  'commission_duration': 'first_payment_only',
  'active': true,
  'created_at': '2026-08-30T10:00:00Z',
  'linked_tenants_count': 2,
  'pending_commissions_cop': 36000,
  'paid_commissions_cop': 0,
};

void main() {
  group('partnerPayoutChannelLabel / partnerCommissionDurationLabel (D-173)', () {
    test('traduce cada canal de pago a su etiqueta legible', () {
      expect(partnerPayoutChannelLabel('bre_b'), 'Llave Bre-B');
      expect(partnerPayoutChannelLabel('daviplata'), 'Daviplata');
      expect(partnerPayoutChannelLabel('nequi'), 'Nequi');
      expect(partnerPayoutChannelLabel('bancolombia'), 'Bancolombia');
      expect(partnerPayoutChannelLabel('otro'), 'Otro');
      expect(partnerPayoutChannelLabel(null), 'Sin definir');
    });

    test('traduce cada duración de comisión a su etiqueta legible', () {
      expect(partnerCommissionDurationLabel('first_payment_only'), 'Solo el primer pago');
      expect(partnerCommissionDurationLabel('first_n_months'), 'Primeros meses');
      expect(partnerCommissionDurationLabel('recurring_lifetime'), 'Recurrente, mientras pague');
    });
  });

  group('PlatformPartner.fromMap (D-173)', () {
    test('mapea un partner con comisión porcentual (Bre-B)', () {
      final partner = PlatformPartner.fromMap(_basePartnerMap());

      expect(partner.fullName, 'Carlos Pérez');
      expect(partner.referralCode, 'CARLOS');
      expect(partner.payoutChannelLabel, 'Llave Bre-B');
      expect(partner.commissionType, 'percentage');
      expect(partner.linkedTenantsCount, 2);
      expect(partner.formattedPending, '\$36.000 COP');
    });

    test('commissionLabel muestra el porcentaje sin decimales cuando es entero', () {
      final partner = PlatformPartner.fromMap(_basePartnerMap());
      expect(partner.commissionLabel, '15% · solo el primer pago');
    });

    test('commissionLabel muestra un decimal cuando el porcentaje no es entero', () {
      final map = _basePartnerMap();
      map['commission_value'] = 12.5;
      final partner = PlatformPartner.fromMap(map);
      expect(partner.commissionLabel, '12.5% · solo el primer pago');
    });

    test('commissionLabel de un valor fijo en COP', () {
      final map = _basePartnerMap();
      map['commission_type'] = 'fixed_cop';
      map['commission_value'] = 50000.0;
      map['commission_duration'] = 'recurring_lifetime';
      final partner = PlatformPartner.fromMap(map);
      expect(partner.commissionLabel, '\$50.000 COP · recurrente, mientras pague');
    });

    test('commissionLabel de primeros N meses incluye la cantidad exacta', () {
      final map = _basePartnerMap();
      map['commission_duration'] = 'first_n_months';
      map['duration_months'] = 3;
      final partner = PlatformPartner.fromMap(map);
      expect(partner.commissionLabel, '15% · primeros 3 meses');
    });

    test('un partner inactivo mapea active en falso', () {
      final map = _basePartnerMap();
      map['active'] = false;
      final partner = PlatformPartner.fromMap(map);
      expect(partner.active, isFalse);
    });

    test('referralLink arma el enlace con el origen dado', () {
      final partner = PlatformPartner.fromMap(_basePartnerMap());
      expect(partner.referralLink('https://salonymas.com'), 'https://salonymas.com/?ref=CARLOS');
    });
  });

  group('PlatformPartnerCommission.fromMap (D-173)', () {
    test('una comisión pendiente', () {
      final commission = PlatformPartnerCommission.fromMap({
        'commission_id': 'c1',
        'tenant_id': 't1',
        'tenant_name': 'Salón X',
        'amount_cop': 36000,
        'payment_event_amount_cop': 240000,
        'status': 'pending',
        'created_at': '2026-08-30T10:00:00Z',
      });

      expect(commission.isPending, isTrue);
      expect(commission.isPaid, isFalse);
      expect(commission.formattedAmount, '\$36.000 COP');
    });

    test('una comisión pagada trae medio y referencia', () {
      final commission = PlatformPartnerCommission.fromMap({
        'commission_id': 'c2',
        'tenant_id': 't1',
        'tenant_name': 'Salón X',
        'amount_cop': 50000,
        'payment_event_amount_cop': 200000,
        'status': 'paid',
        'paid_at': '2026-08-30T12:00:00Z',
        'payout_method': 'nequi',
        'payout_reference': 'REF-123',
      });

      expect(commission.isPaid, isTrue);
      expect(commission.payoutReference, 'REF-123');
    });
  });

  group('PlatformPartnerDetail.fromMap (D-173)', () {
    test('mapea salones vinculados y comisiones, y suma solo las pendientes', () {
      final detail = PlatformPartnerDetail.fromMap({
        ..._basePartnerMap(),
        'linked_tenants': [
          {
            'tenant_id': 't1',
            'tenant_name': 'Salón X',
            'subscription_status': 'active',
            'linked_since': '2026-08-01T10:00:00Z',
          },
          {'tenant_id': 't2', 'tenant_name': 'Salón Y'},
        ],
        'commissions': [
          {
            'commission_id': 'c1',
            'tenant_id': 't1',
            'tenant_name': 'Salón X',
            'amount_cop': 36000,
            'payment_event_amount_cop': 240000,
            'status': 'pending',
          },
          {
            'commission_id': 'c2',
            'tenant_id': 't1',
            'tenant_name': 'Salón X',
            'amount_cop': 50000,
            'payment_event_amount_cop': 200000,
            'status': 'paid',
          },
        ],
      });

      expect(detail.linkedTenants.length, 2);
      expect(detail.commissions.length, 2);
      expect(detail.pendingCommissionsCop, 36000);
    });

    test('sin salones ni comisiones, las listas quedan vacías (no null)', () {
      final detail = PlatformPartnerDetail.fromMap(_basePartnerMap());
      expect(detail.linkedTenants, isEmpty);
      expect(detail.commissions, isEmpty);
      expect(detail.pendingCommissionsCop, 0);
    });
  });

  group('PlatformPartnersSummary.fromMap (D-173)', () {
    test('mapea los cuatro KPIs de la pestaña Partners', () {
      final summary = PlatformPartnersSummary.fromMap({
        'active_partners_count': 3,
        'linked_tenants_count': 5,
        'pending_commissions_cop': 136000,
        'paid_commissions_cop': 500000,
      });

      expect(summary.activePartnersCount, 3);
      expect(summary.linkedTenantsCount, 5);
      expect(summary.formattedPending, '\$136.000 COP');
      expect(summary.formattedPaid, '\$500.000 COP');
    });

    test('PlatformPartnersSummary.empty no revienta con campos vacíos', () {
      expect(PlatformPartnersSummary.empty.activePartnersCount, 0);
      expect(PlatformPartnersSummary.empty.formattedPending, '\$0 COP');
    });
  });

  group('PlatformPartnerSettlementResult y PublicPartnerRegistrationResult (D-173)', () {
    test('mapea el resultado de una liquidación', () {
      final result = PlatformPartnerSettlementResult.fromMap({
        'settled_count': 2,
        'settled_amount_cop': 100000,
      });

      expect(result.settledCount, 2);
      expect(result.formattedAmount, '\$100.000 COP');
    });

    test('mapea el resultado de una postulación pública', () {
      final result = PublicPartnerRegistrationResult.fromMap({
        'partner_id': 'p9',
        'referral_code': 'PUBLICO1',
      });

      expect(result.partnerId, 'p9');
      expect(result.referralCode, 'PUBLICO1');
    });
  });

  group('PlatformTenantSummary -- partner vinculado (D-173)', () {
    Map<String, dynamic> baseTenantMap() => {
      'tenant_id': 't1',
      'tenant_name': 'Salón de Prueba',
      'contact_email': 'a@b.com',
      'whatsapp': '3000000000',
      'tenant_active': true,
      'is_demo': false,
      'plan_code': 'profesional',
      'subscription_status': 'active',
      'trial_ends_at': null,
      'current_period_end': null,
      'grace_ends_at': null,
      'created_at': null,
    };

    test('mapea partner_id, partner_name y referral_code_used', () {
      final map = baseTenantMap();
      map['partner_id'] = 'p1';
      map['partner_name'] = 'Carlos Pérez';
      map['referral_code_used'] = 'CARLOS';

      final tenant = PlatformTenantSummary.fromMap(map);

      expect(tenant.partnerId, 'p1');
      expect(tenant.partnerName, 'Carlos Pérez');
      expect(tenant.referralCodeUsed, 'CARLOS');
    });

    test('sin partner vinculado, los tres campos quedan null', () {
      final tenant = PlatformTenantSummary.fromMap(baseTenantMap());

      expect(tenant.partnerId, isNull);
      expect(tenant.partnerName, isNull);
      expect(tenant.referralCodeUsed, isNull);
    });
  });
}
