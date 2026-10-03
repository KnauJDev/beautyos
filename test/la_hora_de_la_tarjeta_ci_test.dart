import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/ticket_board.dart';

/// Hallazgo CI (03-oct): la tarjeta de la cita en la agenda ponía 14:00 a una
/// cita de las 09:00, porque la hora llega en UTC y no se pasaba a la del
/// equipo. El recordatorio de WhatsApp usa esa misma hora y se la decía mal
/// a la clienta. Lo vio el propietario en el espejo de David.
void main() {
  final cita = TicketBoardItem.fromMap({
    'id': 't',
    'scheduled_at': '2026-10-03T14:00:00+00:00',
    'closed_at': '2026-10-03T15:00:00+00:00',
    'status': 'finalizado',
  });

  test('la hora de la cita queda en la hora del equipo, no en UTC', () {
    final esperada = DateTime.parse('2026-10-03T14:00:00+00:00').toLocal();
    expect(cita.scheduledAt!.isUtc, isFalse);
    expect(cita.scheduledAt, esperada);
    expect(cita.scheduledAt!.hour, esperada.hour);
  });

  test('la hora de cierre también', () {
    expect(cita.closedAt!.isUtc, isFalse);
  });
}
