import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/enlace_de_reserva.dart';
import 'package:salonymas/pages/agenda_page.dart' show textoDeSinEfecto;
import 'package:salonymas/pages/settings_page.dart'
    show textoDeLaTarjetaDeReserva;
import 'package:salonymas/widgets/compartir_reserva_del_estilista.dart'
    show mensajeDeLaEstilista;
import 'package:salonymas/widgets/elegir_fecha.dart';

/// Leído con los saltos de línea normalizados.
String leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Lo que salió el 03-oct cuando el propietario reservó como clienta desde el
/// celular, en el espejo de David: el calendario en inglés y con "OK" (CJ),
/// la confirmación sin salida clara, dos textos viejos y el enlace de la
/// estilista sin el nombre del salón.
void main() {
  group('CJ: la app habla español', () {
    test('MaterialApp declara el español de Colombia y sus traducciones', () {
      final main = leer('lib/main.dart');
      expect(main, contains("locale: const Locale('es', 'CO'),"));
      expect(
        main,
        contains('localizationsDelegates: GlobalMaterialLocalizations.delegates,'),
      );
    });

    testWidgets('con esa configuración, Flutter dice "Cancelar" y no "Cancel"',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es', 'CO'),
          supportedLocales: const [Locale('es', 'CO'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(MaterialLocalizations.of(ctx).cancelButtonLabel.toLowerCase(),
          'cancelar');
    });
  });

  group('CJ: el calendario elige con un toque', () {
    testWidgets('tocar el día lo elige y cierra, sin "OK"', (tester) async {
      DateTime? elegida;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                elegida = await elegirFechaDeUnToque(
                  context,
                  fechaInicial: DateTime(2026, 10, 3),
                  primeraFecha: DateTime(2026, 10, 1),
                  ultimaFecha: DateTime(2026, 12, 31),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(elegida, DateTime(2026, 10, 15));
    });

    test('lo usan los cuatro calendarios de agendar', () {
      // La reserva pública, el salto de fecha del tablero y Mi agenda ya no
      // tienen ningún otro. Tickets & Caja conserva tres de Flutter (filtros
      // y reprogramar), ahora en español: solo cambió el de la cita nueva.
      for (final ruta in [
        'lib/pages/public_booking_page.dart',
        'lib/pages/agenda_page.dart',
        'lib/pages/my_stylist_agenda_page.dart',
      ]) {
        final codigo = leer(ruta);
        expect(codigo, contains('elegirFechaDeUnToque('), reason: ruta);
        expect(codigo, isNot(contains('showDatePicker(')), reason: ruta);
      }
      expect(
        leer('lib/pages/tickets_page.dart'),
        contains('elegirFechaDeUnToque('),
      );
    });
  });

  test('la confirmación tiene un "Listo" que termina', () {
    final reserva = leer('lib/pages/public_booking_page.dart');
    expect(reserva, contains("child: const Text('Listo'),"));
    expect(reserva, contains("'Listo. Ya puedes cerrar esta página.',"));
    expect(
      reserva,
      isNot(contains("label: const Text('Volver a la página del salón')")),
    );
  });

  group('textos viejos', () {
    test('"1 cancelada", en singular', () {
      expect(textoDeSinEfecto(1, 0), '1 cancelada · 0 no asistió');
      expect(textoDeSinEfecto(2, 1), '2 canceladas · 1 no asistió');
    });

    test('sin caja, la tarjeta del enlace no dice "pendiente"', () {
      expect(
        textoDeLaTarjetaDeReserva(citasNacenConfirmadas: true),
        isNot(contains('pendiente')),
      );
      expect(
        textoDeLaTarjetaDeReserva(citasNacenConfirmadas: false),
        contains('pendiente'),
      );
      expect(leer('lib/main.dart'), contains("isOwner: role == 'owner',\n"
          '          // D-312: sin caja, la tarjeta del enlace no dice "pendiente".\n'
          '          citasNacenConfirmadas: cajaOculta,'));
    });
  });

  group('el enlace de la estilista lleva el nombre del salón', () {
    const origen = 'https://salonymas.com';

    test('de la sede principal y con dirección: la página del salón', () {
      expect(
        enlaceParaCompartir(
          branchId: 'sede-1',
          esSedePrincipal: true,
          slugDelSalon: 'peluqueria-exito',
          origen: origen,
        ),
        'https://salonymas.com/peluqueria-exito',
      );
    });

    test('de otra sede: el enlace de su sede, para no reservar en la principal',
        () {
      expect(
        enlaceParaCompartir(
          branchId: 'sede-2',
          esSedePrincipal: false,
          slugDelSalon: 'peluqueria-exito',
          origen: origen,
        ),
        'https://salonymas.com/?reservar=sede-2',
      );
    });

    test('sin dirección conocida: el de siempre', () {
      expect(
        enlaceParaCompartir(
          branchId: 'sede-1',
          esSedePrincipal: true,
          slugDelSalon: null,
          origen: origen,
        ),
        'https://salonymas.com/?reservar=sede-1',
      );
    });

    test('el mensaje nombra el salón', () {
      expect(
        mensajeDeLaEstilista(
          enlace: 'https://salonymas.com/peluqueria-exito',
          nombreDelSalon: 'Peluquería Éxito',
        ),
        startsWith('Reserva tu cita conmigo en Peluquería Éxito aquí 👉 '),
      );
      expect(
        mensajeDeLaEstilista(enlace: 'x', nombreDelSalon: null),
        startsWith('Reserva tu cita conmigo aquí 👉 x'),
      );
    });

    test('la dirección se pide por la sede, con la función pública, no leyendo la tabla',
        () {
      // La lectura del 03-oct: leer `tenants` con la sesión de la estilista se
      // niega ("permission denied for table tenant_memberships").
      final servicio = leer('lib/services/slug_del_salon_service.dart');
      expect(servicio, contains("'public_get_salon_slug_by_branch'"));
      expect(servicio, isNot(contains(".from('tenants')")));
      final m = leer(
        'supabase/migrations/20261003150000_la_direccion_del_salon_por_sede_d313.sql',
      );
      expect(m, contains('security definer'));
      expect(
        m,
        contains(
          'grant execute on function public.public_get_salon_slug_by_branch(uuid) to anon, authenticated;',
        ),
      );
      expect(m.toLowerCase(), isNot(contains('drop function')));
      expect(
        leer('supabase/sql/241_test_la_direccion_del_salon_por_sede.sql'),
        contains('--- CONTROL 241: 6/6 ---'),
      );
    });

    test('D-313: Configuración sigue la misma regla', () {
      final ajustes = leer('lib/pages/settings_page.dart');
      expect(ajustes, contains('slugDelSalon: snapshot.data?.slug,'));
      expect(ajustes, contains('esSedePrincipal: widget.esSedePrincipal,'));
      expect(
        'esSedePrincipal: branch.isPrimary,'.allMatches(leer('lib/main.dart')).length,
        4,
        reason: 'la estilista, Configuración, Clientes (4A) y la Agenda (4B)',
      );
    });

    test('main le pasa a la estilista su salón y si es la sede principal', () {
      final main = leer('lib/main.dart');
      expect(main, contains('nombreDelSalon: branch.tenantName,'));
      expect(main, contains('esSedePrincipal: branch.isPrimary,'));
    });
  });
}
