import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_partner.dart';

/// Auto-registro público de partners (D-173): `salonymas.com/partners`.
/// Llama a `public_register_partner`, accesible sin sesión (rol anon).
class PublicPartnerService {
  const PublicPartnerService();

  Future<PublicPartnerRegistrationResult> registerPartner({
    required String fullName,
    String? documentId,
    required String referralCode,
    String? phone,
    required String whatsapp,
    String? email,
    required String payoutChannel,
    required String payoutAccount,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'public_register_partner',
      params: {
        'p_full_name': fullName,
        'p_document_id': documentId,
        'p_referral_code': referralCode,
        'p_phone': phone,
        'p_whatsapp': whatsapp,
        'p_email': email,
        'p_payout_channel': payoutChannel,
        'p_payout_account': payoutAccount,
      },
    );
    final rows = response as List;
    return PublicPartnerRegistrationResult.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
