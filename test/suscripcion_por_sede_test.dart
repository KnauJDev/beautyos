import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/branch_subscription.dart';

void main() {
  Map<String, dynamic> fila({
    String status = 'active',
    bool alDia = true,
    bool isPrimary = false,
    String? periodEnd,
    String? activatedAt,
    Object? precio = 150000,
  }) => {
    'branch_id': '11111111-1111-1111-1111-111111111111',
    'branch_name': 'Sede Chapinero',
    'is_primary': isPrimary,
    'branch_active': true,
    'status': status,
    'al_dia': alDia,
    'precio_cop': precio,
    'motivo_precio': 'Precio de lista',
    'current_period_end': periodEnd,
    'activated_at': activatedAt,
  };

  group('Etapa 3b — El estado de pago de una sede llega a la pantalla', () {
    test('fromMap lee lo que devuelve get_branch_subscriptions()', () {
      final s = BranchSubscription.fromMap(
        fila(
          isPrimary: true,
          periodEnd: '2026-10-02T00:00:00Z',
          activatedAt: '2026-09-02T00:00:00Z',
        ),
      );

      expect(s.branchName, 'Sede Chapinero');
      expect(s.isPrimary, true);
      expect(s.alDia, true);
      expect(s.precioCop, 150000);
      expect(s.currentPeriodEnd, isNotNull);
      expect(s.nuncaActivada, false);
    });

    test('una sede que nunca se activó se distingue de una que se cayó', () {
      // No es lo mismo un local que se dio de alta y jamás se pagó que uno que
      // llevaba meses al día y se atrasó. Al primero se le dice "activar"; al
      // segundo, "ponerla al día".
      final nueva = BranchSubscription.fromMap(
        fila(status: 'pending', alDia: false),
      );
      final caida = BranchSubscription.fromMap(
        fila(
          status: 'past_due',
          alDia: false,
          activatedAt: '2026-07-01T00:00:00Z',
        ),
      );

      expect(nueva.nuncaActivada, true);
      expect(nueva.etiquetaEstado, 'Pendiente de activar');

      expect(caida.nuncaActivada, false);
      expect(caida.etiquetaEstado, 'Pago vencido');
    });

    test('los estados se traducen al idioma del dueño, no al de la base', () {
      String etiqueta(String status) => BranchSubscription.fromMap(
        fila(status: status, alDia: false, activatedAt: '2026-07-01T00:00:00Z'),
      ).etiquetaEstado;

      expect(etiqueta('grace'), 'En período de gracia');
      expect(etiqueta('suspended'), 'Suspendida');
      expect(etiqueta('cancelled'), 'Cancelada');
      // Un estado que no conozcamos no debe dejar la etiqueta en blanco.
      expect(etiqueta('lo_que_sea'), isNotEmpty);
    });

    test('al día manda sobre el estado crudo', () {
      // `al_dia` lo calcula el servidor para que signifique lo mismo en los dos
      // lados. Si viniera en true, la etiqueta no debe contradecirlo.
      final s = BranchSubscription.fromMap(
        fila(status: 'trialing', alDia: true),
      );

      expect(s.etiquetaEstado, 'Al día');
    });

    test('un precio que llega como texto o ausente no rompe la pantalla', () {
      expect(BranchSubscription.fromMap(fila(precio: '150000')).precioCop, 150000);
      expect(BranchSubscription.fromMap(fila(precio: null)).precioCop, 0);
    });
  });
}
