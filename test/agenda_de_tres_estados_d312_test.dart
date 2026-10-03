import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/agenda_de_tres_estados.dart';
import 'package:salonymas/models/public_booking_result.dart';
import 'package:salonymas/models/ticket_board.dart';
import 'package:salonymas/pages/agenda_page.dart';
import 'package:salonymas/pages/public_booking_page.dart';
import 'package:salonymas/widgets/compartir_reserva_del_estilista.dart';
import 'package:salonymas/widgets/ticket_status.dart';

/// Lee un archivo del proyecto con los saltos de línea normalizados.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// D-312, paso 2 del plan del primer cliente real (D-308): a un negocio con
/// la caja apagada por la plataforma, toda cita le nace confirmada y su
/// agenda va Confirmado -> En proceso -> Cerrado, con los botones en la cita.
void main() {
  group('las tres columnas', () {
    test('con la caja apagada, el tablero tiene tres; si no, las de siempre', () {
      expect(
        ColumnaDeAgenda.delDia(tresEstados: true).map((c) => c.titulo),
        ['Confirmado', 'En proceso', 'Cerrado'],
      );
      expect(
        ColumnaDeAgenda.deLaSemana(tresEstados: true).map((c) => c.titulo),
        ['Confirmado', 'En proceso', 'Cerrado'],
      );
      expect(
        ColumnaDeAgenda.delDia(tresEstados: false).map((c) => c.titulo),
        DayBoardColumn.values.map((c) => c.titulo),
      );
      expect(
        ColumnaDeAgenda.deLaSemana(tresEstados: false).map((c) => c.titulo),
        WeekBoardColumn.values.map((c) => c.titulo),
      );
    });

    test('ningún estado se queda sin columna, y ninguno cae en dos', () {
      const todos = [
        'solicitado',
        'cotizado',
        'apartado',
        'confirmado',
        'en_espera',
        'en_proceso',
        'finalizado',
        'cerrado',
      ];
      for (final estado in todos) {
        final columnas = ColumnaDeAgenda.deTresEstados
            .where((c) => c.contiene(estado))
            .length;
        expect(columnas, 1, reason: estado);
      }
      for (final estado in ['cancelado', 'no_asistio']) {
        expect(
          ColumnaDeAgenda.deTresEstados.any((c) => c.contiene(estado)),
          isFalse,
          reason: '$estado queda fuera de las columnas, como hoy',
        );
      }
    });

    test('"finalizado" es Cerrado: sin caja no hay "Por cobrar"', () {
      expect(ColumnaDeAgenda.deTresEstados.last.contiene('finalizado'), isTrue);
      expect(
        AgendaDeTresEstados.comoSeMuestra('finalizado'),
        TicketStatus.cerrado,
      );
      expect(
        AgendaDeTresEstados.comoSeMuestra('solicitado'),
        TicketStatus.confirmado,
      );
    });
  });

  group('los botones de cada cita', () {
    test('antes de empezar: los cuatro', () {
      for (final e in ['solicitado', 'confirmado', 'en_espera']) {
        expect(AgendaDeTresEstados.acciones(e), AccionDeTresEstados.values);
      }
    });

    test('en proceso: solo Cerrar (el servidor no deja cancelar lo empezado)', () {
      expect(AgendaDeTresEstados.acciones('en_proceso'), [
        AccionDeTresEstados.cerrar,
      ]);
    });

    test('cerrada, cancelada o no asistió: ninguno', () {
      for (final e in ['finalizado', 'cerrado', 'cancelado', 'no_asistio']) {
        expect(AgendaDeTresEstados.acciones(e), isEmpty, reason: e);
      }
    });

    test('solo Cancelar y No asistió piden motivo', () {
      expect(
        AccionDeTresEstados.values.where((a) => a.pideMotivo),
        [AccionDeTresEstados.cancelar, AccionDeTresEstados.noAsistio],
      );
    });
  });

  group('los pasos que da cada botón', () {
    const dos = <ServicioDeCita>[
      (id: 's1', estado: 'pendiente'),
      (id: 's2', estado: 'pendiente'),
    ];

    List<String> pasos(
      AccionDeTresEstados a,
      String estado,
      List<ServicioDeCita> servicios, {
      String? motivo,
    }) => AgendaDeTresEstados.pasos(
      a,
      estadoDelTicket: estado,
      servicios: servicios,
      motivo: motivo,
    ).map((p) => p.toString()).toList();

    test('Iniciar una confirmada: arranca sus servicios', () {
      expect(pasos(AccionDeTresEstados.iniciar, 'confirmado', dos), [
        'servicio s1->en_proceso',
        'servicio s2->en_proceso',
      ]);
    });

    test('Cerrar desde Confirmado: primero inicia todos, después termina todos', () {
      // Terminar un servicio exige el ticket en proceso; por eso el orden.
      expect(pasos(AccionDeTresEstados.cerrar, 'confirmado', dos), [
        'servicio s1->en_proceso',
        'servicio s2->en_proceso',
        'servicio s1->finalizado',
        'servicio s2->finalizado',
      ]);
    });

    test('Cerrar a medias: no repite lo que ya está hecho', () {
      expect(
        pasos(AccionDeTresEstados.cerrar, 'en_proceso', const [
          (id: 's1', estado: 'finalizado'),
          (id: 's2', estado: 'en_proceso'),
          (id: 's3', estado: 'cancelado'),
        ]),
        ['servicio s2->finalizado'],
      );
    });

    test('una cita vieja "por confirmar" se confirma por dentro antes', () {
      expect(pasos(AccionDeTresEstados.iniciar, 'solicitado', dos).first,
          'ticket->confirmado');
      expect(pasos(AccionDeTresEstados.cerrar, 'cotizado', dos).first,
          'ticket->confirmado');
      expect(
        pasos(AccionDeTresEstados.noAsistio, 'solicitado', dos, motivo: 'x'),
        ['ticket->confirmado', 'ticket->no_asistio'],
      );
    });

    test('Cancelar va directo y lleva su motivo', () {
      final p = AgendaDeTresEstados.pasos(
        AccionDeTresEstados.cancelar,
        estadoDelTicket: 'solicitado',
        servicios: dos,
        motivo: 'Avisó que no puede',
      );
      expect(p.single.nuevoEstado, 'cancelado');
      expect(p.single.motivo, 'Avisó que no puede');
    });

    test('ningún paso toca dinero: solo estados de cita y de servicio', () {
      for (final a in AccionDeTresEstados.values) {
        for (final e in ['solicitado', 'confirmado', 'en_proceso']) {
          for (final p in AgendaDeTresEstados.pasos(
            a,
            estadoDelTicket: e,
            servicios: dos,
            motivo: 'm',
          )) {
            expect(p.nuevoEstado, isNot('cerrado'), reason: '$a desde $e');
          }
        }
      }
    });
  });

  group('lo que dice la pantalla', () {
    test('el tablero sin caja no habla de cobro', () {
      expect(subtituloDelTablero(tresEstados: true), isNot(contains('cobro')));
      expect(subtituloDelTablero(tresEstados: false), contains('cobro'));
      expect(textoDePendientesDeCierre(1, tresEstados: true), '1 cita sin cerrar');
      expect(textoDePendientesDeCierre(3, tresEstados: true), '3 citas sin cerrar');
      expect(
        textoDePendientesDeCierre(1),
        '1 ticket pendiente de cierre comercial',
      );
      expect(
        textoDeJornadaAlDia(tresEstados: true),
        isNot(contains('columnas')),
      );
    });

    test('la clienta lee "confirmada" si su cita nació confirmada', () {
      final confirmada = PublicBookingResult.fromMap({
        'ticket_id': 't',
        'scheduled_at': '2026-10-05T15:00:00Z',
        'status': 'confirmado',
      });
      final solicitada = PublicBookingResult.fromMap({
        'ticket_id': 't',
        'scheduled_at': '2026-10-05T15:00:00Z',
        'status': 'solicitado',
      });
      expect(confirmada.confirmada, isTrue);
      expect(solicitada.confirmada, isFalse);
      expect(
        mensajeDeWhatsAppDeLaReserva(
          clientName: 'Ana',
          serviceName: 'Corte',
          fecha: '05/10/2026 10:00',
          confirmada: true,
        ),
        isNot(contains('¿Me confirman?')),
      );
      expect(
        mensajeDeWhatsAppDeLaReserva(
          clientName: 'Ana',
          serviceName: 'Corte',
          fecha: '05/10/2026 10:00',
          confirmada: false,
        ),
        contains('¿Me confirman?'),
      );
    });

    test('la estilista no lee "por confirmar" si nace confirmada', () {
      expect(
        textoDeCompartirReserva(citasNacenConfirmadas: true),
        isNot(contains('por confirmar')),
      );
      expect(
        textoDeCompartirReserva(citasNacenConfirmadas: false),
        contains('por confirmar'),
      );
    });

    test('el aviso de cada botón dice lo que pasó', () {
      expect(
        avisoDeAccionHecha(AccionDeTresEstados.cerrar, 'Ana'),
        'La cita de Ana quedó cerrada.',
      );
    });
  });

  group('el cableado', () {
    final main = leer('lib/main.dart');
    final agenda = leer('lib/pages/agenda_page.dart');

    test('la agenda y la estilista se encienden con la caja apagada', () {
      expect(main, contains('tresEstados: cajaOculta,'));
      expect(main, contains('citasNacenConfirmadas: cajaOculta,'));
    });

    test('el tablero pinta sus columnas, no las enumeraciones fijas', () {
      expect(agenda, isNot(contains('DayBoardColumn.values')));
      expect(agenda, isNot(contains('WeekBoardColumn.values')));
      expect(agenda, contains('ColumnaDeAgenda.delDia('));
    });

    test('sin caja, la tarjeta cambia el dinero por los botones', () {
      expect(agenda, contains('if (tresEstados)\n            _BotonesDeLaCita('));
    });

    test('los botones usan las funciones de siempre, con su historial', () {
      expect(agenda, contains('tickets.changeTicketStatus('));
      expect(agenda, contains('tickets.changeTicketServiceStatus('));
      expect(agenda, isNot(contains('registerTicketPayment')));
    });
  });

  group('el servidor', () {
    final m = leer(
      'supabase/migrations/20261003100000_agenda_de_tres_estados_d312.sql',
    );

    test('la pregunta vive en un sitio y mira que la caja la apagara el Panel', () {
      expect(
        m,
        contains(
          'create or replace function private.beautyos_agenda_de_tres_estados',
        ),
      );
      expect(m, contains("not r.entitled and r.source = 'override'"));
      expect(
        m,
        contains(
          'revoke all on function private.beautyos_agenda_de_tres_estados(uuid) from public, anon, authenticated;',
        ),
      );
    });

    test('las dos puertas cambian, y solo el estado con que nace la cita', () {
      expect(
        m,
        contains('CREATE OR REPLACE FUNCTION public.public_create_booking('),
      );
      expect(
        m,
        contains(
          'CREATE OR REPLACE FUNCTION public.create_scheduled_ticket_with_service_v2(',
        ),
      );
      expect('-- D-312: EL UNICO CAMBIO.'.allMatches(m).length, 2);
      expect(
        "then 'confirmado' else 'solicitado' end,".allMatches(m).length,
        2,
      );
    });

    test('no toca dinero ni otras funciones', () {
      final bajo = m.toLowerCase();
      expect(bajo, isNot(contains('ticket_payments set')));
      expect(bajo, isNot(contains('insert into public.stylist_commissions')));
      expect(
        'create or replace function'.allMatches(bajo).length,
        3,
        reason: 'la pregunta y las dos puertas',
      );
    });

    test('el control 240 existe y recorre las dos puertas sin dinero', () {
      final c = leer('supabase/sql/240_test_agenda_de_tres_estados.sql');
      expect(c, contains('--- CONTROL 240: 9/9 ---'));
      expect(c, contains('public_create_booking('));
      expect(c, contains('create_scheduled_ticket_with_service_v2('));
      expect(c, contains('create_recurring_scheduled_tickets_v2('));
      expect(c, contains('stylist_commissions'));
      expect(c.trimRight(), endsWith('rollback;'));
    });
  });
}
