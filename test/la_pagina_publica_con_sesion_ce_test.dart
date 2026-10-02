import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/models/mensaje_para_la_clienta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CE (D-307): con una sesión abierta, la página pública enseñaba
/// "permission denied for function public_get_branch_booking_info", en inglés
/// y con el nombre de una función interna (contra D-208).
void main() {
  group('lo técnico se cambia por una frase humana', () {
    test('el caso real del 02-oct', () {
      final m = mensajeParaLaClienta(
        const PostgrestException(
          message: 'permission denied for function public_get_branch_booking_info',
          code: '42501',
        ),
      );
      expect(m, algoFalloDeNuestroLado);
      expect(m, isNot(contains('permission')));
      expect(m, isNot(contains('public_')));
    });

    test('una función o una tabla que no aparece, o un error de la API', () {
      for (final codigo in ['42883', '42P01', '42703', 'PGRST202', '08006', '57014']) {
        expect(
          mensajeParaLaClienta(PostgrestException(message: 'algo interno', code: codigo)),
          algoFalloDeNuestroLado,
          reason: codigo,
        );
      }
    });

    test('sin conexión, se dice que es la conexión', () {
      expect(mensajeParaLaClienta(TimeoutException('x')), sinConexion);
      expect(mensajeParaLaClienta(Exception('ClientException: Failed to fetch')), sinConexion);
    });

    test('cualquier otra cosa rara no se enseña cruda', () {
      expect(mensajeParaLaClienta(StateError('Bad state: null')), algoFalloDeNuestroLado);
    });
  });

  group('lo que el servidor escribe para la clienta pasa tal cual', () {
    test('un raise exception (P0001) se enseña', () {
      const texto = 'Ese horario ya no está disponible. Elige otro.';
      expect(
        mensajeParaLaClienta(const PostgrestException(message: texto, code: 'P0001')),
        texto,
      );
    });

    test('la reserva sigue reconociendo "Ese horario ya no" (AX)', () {
      // public_booking_page.dart lee este texto para recargar las horas.
      final m = mensajeParaLaClienta(
        const PostgrestException(message: 'Ese horario ya no está disponible.', code: 'P0001'),
      );
      expect(m, contains('Ese horario ya no'));
    });
  });

  group('las dos páginas públicas usan el mensaje compartido', () {
    for (final pagina in ['public_booking_page.dart', 'public_review_page.dart']) {
      test(pagina, () {
        final codigo = File('lib/pages/$pagina').readAsStringSync();
        expect(codigo, contains('mensajeParaLaClienta('));
        expect(codigo, isNot(contains('_friendlyError')));
        expect(codigo, isNot(contains('error.message')));
      });
    }
  });

  test('la migración da permiso a authenticated en las seis, sin quitárselo a anon', () {
    final m = File(
      'supabase/migrations/20261002100000_la_pagina_publica_tambien_con_sesion_ce.sql',
    ).readAsStringSync();
    expect('to authenticated;'.allMatches(m).length, 6);
    expect(m, isNot(contains('revoke')));
    expect(m.trimRight(), endsWith('commit;'));
  });
}
