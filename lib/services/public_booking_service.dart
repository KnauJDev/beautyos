import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/available_appointment_slot.dart';
import '../models/public_booking_result.dart';
import '../models/public_branch_info.dart';
import '../models/public_service_option.dart';

/// Llama a las RPC publicas (rol "anon", sin sesion) usadas por la pagina
/// de reserva publica. Ninguna de estas funciones exige login.
class PublicBookingService {
  const PublicBookingService();

  Future<PublicBranchInfo> getBranchInfo(String branchId) async {
    final response = await Supabase.instance.client.rpc(
      'public_get_branch_booking_info',
      params: {'p_branch_id': branchId},
    );

    final rows = response as List;
    return PublicBranchInfo.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<List<PublicServiceOption>> getBookableServices(
    String branchId,
  ) async {
    final response = await Supabase.instance.client.rpc(
      'public_get_bookable_services',
      params: {'p_branch_id': branchId},
    );

    return (response as List)
        .map<PublicServiceOption>(
          (item) => PublicServiceOption.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<AvailableAppointmentSlot>> getAvailableSlots({
    required String branchId,
    required String serviceId,
    required String stylistId,
    required DateTime date,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'public_get_available_slots',
      params: {
        'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      },
    );

    return (response as List)
        .map<AvailableAppointmentSlot>(
          (item) => AvailableAppointmentSlot.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<PublicBookingResult> createBooking({
    required String branchId,
    required String serviceId,
    required String stylistId,
    required DateTime scheduledAt,
    required String clientName,
    required String clientPhone,
    String? clientEmail,
    String? notes,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'public_create_booking',
      params: {
        'p_branch_id': branchId,
        'p_service_id': serviceId,
        'p_stylist_id': stylistId,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_client_name': clientName,
        'p_client_phone': clientPhone,
        'p_client_email': clientEmail,
        'p_notes': notes,
      },
    );

    final rows = response as List;
    return PublicBookingResult.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
