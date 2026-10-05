import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/invitacion_a_volver.dart';
import 'package:salonymas/pages/services_page.dart' show leerTiempoDeVolver;
import 'package:salonymas/services/invitar_a_volver_service.dart';
import 'package:salonymas/widgets/para_invitar_hoy.dart';

String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Un servicio de invitaciones de mentira: devuelve filas fijas y no toca la
/// base.
class _Falso extends InvitarAVolverService {
  _Falso(this.filas) : super(branchId: 'sede-1');

  final List<InvitacionAVolver> filas;

  @override
  Future<List<InvitacionAVolver>> listar() async => filas;
}

InvitacionAVolver fila({
  required String cliente,
  required String servicio,
  required bool tocaHoy,
  String estado = 'por_invitar',
  DateTime? invitada,
  int veces = 0,
  DateTime? ultima,
}) => InvitacionAVolver(
  clientId: 'c-$cliente',
  clientName: cliente,
  clientPhone: '3001234567',
  serviceId: 's-$servicio',
  serviceName: servicio,
  lastDoneAt: ultima ?? DateTime(2026, 9, 8),
  returnDays: 20,
  estado: estado,
  tocaHoy: tocaHoy,
  lastInvitedAt: invitada,
  timesInvited: veces,
);

/// D-314, paso 4B: invitar a volver, por servicio. Lo que no se puede ver
/// desde aquí lo prueba el control 242 en el servidor.
void main() {
  final hoy = DateTime(2026, 10, 3, 15);

  group('cada fila es una clienta y UN servicio', () {
    test('se lee de get_return_invitations', () {
      final f = InvitacionAVolver.fromMap({
        'client_id': 'c1',
        'client_name': 'Ana María Gómez',
        'client_phone': '3001234567',
        'service_id': 's1',
        'service_name': 'Rubber',
        'last_done_at': '2026-09-08T14:00:00Z',
        'return_days': 20,
        'last_invited_at': null,
        'times_invited': 0,
        'estado': 'por_invitar',
        'toca_hoy': true,
      });
      expect(f.primerNombre, 'Ana');
      expect(f.tocaHoy, isTrue);
      expect(f.invitadaSinVolver, isFalse);
      expect(f.lastDoneAt.isUtc, isFalse, reason: 'la hora va en la del equipo (CI)');
    });

    test('dice en qué va: última vez, o invitada y cuántas veces', () {
      expect(
        fila(cliente: 'Ana', servicio: 'Rubber', tocaHoy: true).textoDeEstado(hoy),
        'Última vez hace 25 días',
      );
      expect(
        fila(
          cliente: 'Ana',
          servicio: 'Rubber',
          tocaHoy: false,
          estado: 'invitada_sin_volver',
          invitada: DateTime(2026, 10, 2),
          veces: 1,
        ).textoDeEstado(hoy),
        'Invitada ayer',
      );
      expect(
        fila(
          cliente: 'Ana',
          servicio: 'Rubber',
          tocaHoy: true,
          estado: 'invitada_sin_volver',
          invitada: DateTime(2026, 9, 10),
          veces: 2,
        ).textoDeEstado(hoy),
        'Invitada hace 23 días (2 veces)',
      );
    });

    test('las clientas se cuentan una vez aunque tengan dos servicios', () {
      final filas = [
        fila(cliente: 'Ana', servicio: 'Rubber', tocaHoy: true),
        fila(cliente: 'Ana', servicio: 'Tinte', tocaHoy: true),
        fila(cliente: 'Bea', servicio: 'Corte', tocaHoy: true),
      ];
      expect(clientasDe(filas).length, 2);
      expect(tituloDeParaInvitarHoy(1), 'Para invitar hoy (1 clienta)');
      expect(tituloDeParaInvitarHoy(2), 'Para invitar hoy (2 clientas)');
    });
  });

  test('el WhatsApp nombra el salón, el servicio y el enlace', () {
    final m = mensajeDeInvitacionAVolver(
      nombre: 'Ana',
      servicio: 'Rubber',
      nombreDelSalon: 'Inspirant Salon',
      enlace: 'https://salonymas.com/inspirant-salon',
    );
    expect(m, startsWith('Hola Ana, ¡te extrañamos en Inspirant Salon!'));
    expect(m, contains('para tu rubber.'));
    expect(m, endsWith('agenda aquí 👉 https://salonymas.com/inspirant-salon'));
  });

  group('el tiempo de volver de un servicio', () {
    test('vacío es "el del salón"', () {
      final t = leerTiempoDeVolver('  ');
      expect(t.dias, isNull);
      expect(t.error, isNull);
    });
    test('de 1 a 365', () {
      expect(leerTiempoDeVolver('20').dias, 20);
      expect(leerTiempoDeVolver('0').error, isNotNull);
      expect(leerTiempoDeVolver('400').error, isNotNull);
      expect(leerTiempoDeVolver('veinte').error, isNotNull);
    });
  });

  group('la tarjeta "Para invitar hoy"', () {
    testWidgets('enseña solo las que tocan hoy, con su botón', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParaInvitarHoyCard(
              servicio: _Falso([
                fila(cliente: 'Ana', servicio: 'Rubber', tocaHoy: true),
                fila(cliente: 'Ana', servicio: 'Tinte', tocaHoy: false,
                    estado: 'invitada_sin_volver', invitada: DateTime(2026, 10, 1)),
                fila(cliente: 'Bea', servicio: 'Corte', tocaHoy: true),
              ]),
              reloj: () => hoy,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Para invitar hoy (2 clientas)'), findsOneWidget);
      await tester.tap(find.text('Para invitar hoy (2 clientas)'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bea'), findsOneWidget);
      expect(find.textContaining('Tinte'), findsNothing,
          reason: 'el tinte de Ana no toca hoy');
      expect(find.text('Invitar'), findsNWidgets(2));
    });

    testWidgets('si nadie toca hoy, no ocupa espacio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParaInvitarHoyCard(
              servicio: _Falso([
                fila(cliente: 'Ana', servicio: 'Tinte', tocaHoy: false,
                    estado: 'invitada_sin_volver', invitada: DateTime(2026, 10, 1)),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Para invitar hoy'), findsNothing);
    });
  });

  group('el cableado', () {
    final main = leer('lib/main.dart');

    test('la Agenda y Clientes reciben el servicio de invitaciones', () {
      // Tres desde el 04-oct: el Dashboard de atenciones (D-317) también
      // muestra "Para invitar hoy" y las que no volvieron.
      expect(
        'paraInvitar: InvitarAVolverService(branchId: branch.branchId),'
            .allMatches(main)
            .length,
        3,
      );
    });

    test('la tarjeta va arriba del tablero, solo si hay servicio', () {
      expect(
        leer('lib/pages/agenda_page.dart'),
        contains('if (widget.paraInvitar != null)\n          ParaInvitarHoyCard('),
      );
    });

    test('Clientes tiene los filtros "Para invitar" y "No volvieron"', () {
      final clientes = leer('lib/pages/clients_page.dart');
      expect(clientes, contains("'para_invitar',"));
      expect(clientes, contains("'no_volvieron',"));
      expect(clientes, contains("'Invitar otra vez'"));
    });

    test('Servicios pide el tiempo y Configuración el del salón', () {
      expect(
        leer('lib/pages/services_page.dart'),
        contains("labelText: 'Invitar a volver a los … días',"),
      );
      expect(
        leer('lib/pages/settings_page.dart'),
        contains("const SectionTitle('Invitar a volver'),"),
      );
      expect(
        leer('lib/services/services_service.dart'),
        contains('Future<String?> createService({'),
      );
    });

    test('se registra antes de abrir WhatsApp', () {
      final w = leer('lib/widgets/para_invitar_hoy.dart');
      expect(
        w.indexOf('await servicio.registrar('),
        lessThan(w.indexOf('await launchUrl(')),
      );
    });
  });

  test('la migración solo agrega, y el control prueba el ejemplo del rubber', () {
    final m = leer(
      'supabase/migrations/20261003200000_invitar_a_volver_por_servicio_d314.sql',
    ).toLowerCase();
    expect(m, isNot(contains('drop ')));
    expect('create or replace function'.allMatches(m).length, 5);
    expect(m, contains('revoke all on table public.client_return_invitations from public, anon, authenticated;'));
    final c = leer('supabase/sql/242_test_invitar_a_volver_por_servicio.sql');
    expect(c, contains('--- CONTROL 242: 8/8 ---'));
    expect(c, contains('invitar por el rubber movio el tinte'));
  });
}
