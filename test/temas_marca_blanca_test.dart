import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonymas/theme/app_brand.dart';
import 'package:salonymas/theme/app_colors.dart';

/// Guardian de la marca blanca (tarea 2.4, D-109).
///
/// La tarea 2.2 dejo una prueba que impide escribir colores a mano fuera del
/// tema. Esta cubre el agujero de al lado: **que los temas que si estan en el
/// tema sean usables**.
///
/// Importa porque un tema roto no se ve desde aqui. Solo lo descubre el
/// negocio que lo eligio, en su propia pantalla, y probablemente delante de un
/// cliente.
void main() {
  group('los cinco temas estan completos y se leen', () {
    test('las claves no se repiten y coinciden con la base de datos', () {
      // Estas seis claves estan escritas tambien en la restriccion
      // `tenants_theme_key_valido` de 20260807120000. Si alguien agrega un
      // tema aqui y olvida la migracion, el negocio que lo elija recibe un
      // error de la base de datos.
      const enLaBaseDeDatos = {
        'morado',
        'barberia',
        'spa_unas',
        'clasica',
        'canina',
        'personalizado',
      };

      final enElCodigo = AppBrand.predefinidos
          .map((palette) => palette.key)
          .toSet();

      expect(
        enElCodigo.length,
        AppBrand.predefinidos.length,
        reason: 'Hay dos temas con la misma clave.',
      );

      expect(
        enElCodigo..add(AppBrand.personalizadoKey),
        enLaBaseDeDatos,
        reason:
            'Los temas del codigo y los de la restriccion '
            'tenants_theme_key_valido dejaron de coincidir. Revisa la '
            'migracion 20260807120000.',
      );
    });

    test('el texto blanco se lee sobre la barra superior de cada tema', () {
      for (final palette in AppBrand.predefinidos) {
        final contraste = AppBrand.contrasteConBlanco(palette.brand);

        expect(
          contraste,
          greaterThanOrEqualTo(4.5),
          reason:
              'El tema "${palette.label}" deja el texto blanco de la barra '
              'en ${contraste.toStringAsFixed(2)}:1, por debajo del minimo '
              'AA. Oscurece su color principal.',
        );
      }
    });

    test('los titulos se leen sobre el fondo claro de cada tema', () {
      for (final palette in AppBrand.predefinidos) {
        final contraste = AppBrand.contrasteSobreBlanco(palette.brandDeep);

        expect(
          contraste,
          greaterThanOrEqualTo(4.5),
          reason:
              'Los titulos del tema "${palette.label}" quedan en '
              '${contraste.toStringAsFixed(2)}:1 sobre fondo claro.',
        );
      }
    });

    test('los fondos son claros de verdad, no tonos medios', () {
      for (final palette in AppBrand.predefinidos) {
        for (final entrada in {
          'brandTint': palette.brandTint,
          'brandTintSoft': palette.brandTintSoft,
          'brandSurface': palette.brandSurface,
        }.entries) {
          final luminosidad = HSLColor.fromColor(entrada.value).lightness;

          expect(
            luminosidad,
            greaterThan(0.85),
            reason:
                '${palette.label}.${entrada.key} no es un fondo claro. El '
                'texto oscuro que va encima dejaria de leerse.',
          );
        }
      }
    });
  });

  group('el tema personalizado no puede producir una pantalla ilegible', () {
    test('cualquier color elegido termina admitiendo texto blanco', () {
      // Los peores casos a proposito: blanco puro, amarillo y celeste claro
      // son justo lo que un propietario elegiria pensando en "alegre" y lo que
      // dejaria la barra superior en blanco sobre blanco.
      const candidatos = <Color>[
        Color(0xFFFFFFFF),
        Color(0xFFFFFF00),
        Color(0xFF7DD3FC),
        Color(0xFFFBCFE8),
        Color(0xFF000000),
        Color(0xFF7C3AED),
      ];

      for (final elegido in candidatos) {
        final palette = AppBrand.derivar(elegido);
        final contraste = AppBrand.contrasteConBlanco(palette.brand);

        expect(
          contraste,
          greaterThanOrEqualTo(4.5),
          reason:
              'El color elegido $elegido derivo en una barra con contraste '
              '${contraste.toStringAsFixed(2)}:1.',
        );
      }
    });

    test('todos los colores sugeridos se pueden usar tal cual', () {
      for (final color in AppBrand.coloresSugeridos) {
        expect(
          AppBrand.contrasteConBlanco(color),
          greaterThanOrEqualTo(4.5),
          reason:
              'El color sugerido $color hay que oscurecerlo antes de usarlo, '
              'asi que el propietario no recibiria el que toco. Sacalo de la '
              'lista o cambialo por uno mas oscuro.',
        );
      }
    });

    test('el hex va y vuelve sin perderse', () {
      for (final color in AppBrand.coloresSugeridos) {
        final hex = AppBrand.hexDesdeColor(color);

        expect(hex, matches(r'^#[0-9A-F]{6}$'));
        expect(AppBrand.colorDesdeHex(hex), color);
      }
    });
  });

  group('un dato corrupto no deja al negocio sin pantalla', () {
    test('lo desconocido, vacio o malformado cae en el morado', () {
      final casos = <List<String?>>[
        [null, null],
        ['', null],
        ['   ', null],
        ['tema_que_no_existe', null],
        ['personalizado', null],
        ['personalizado', ''],
        ['personalizado', 'azul'],
        ['personalizado', '#GGGGGG'],
        ['personalizado', '#12345'],
      ];

      for (final caso in casos) {
        expect(
          AppBrand.resolver(caso[0], caso[1]),
          same(AppBrand.morado),
          reason: 'resolver(${caso[0]}, ${caso[1]}) deberia caer en el morado.',
        );
      }
    });

    test('las claves se leen sin importar espacios ni mayusculas', () {
      expect(AppBrand.resolver('  BARBERIA  ', null), same(AppBrand.barberia));
      expect(AppBrand.resolver('Spa_Unas', null), same(AppBrand.spaUnas));
    });
  });

  group('aplicar un tema mueve los colores de marca y nada mas', () {
    tearDown(() => AppBrand.aplicar(null, null));

    test('los seis colores de marca cambian con el tema', () {
      AppBrand.aplicar('canina', null);

      expect(AppColors.brand, AppBrand.canina.brand);
      expect(AppColors.brandDark, AppBrand.canina.brandDark);
      expect(AppColors.brandDeep, AppBrand.canina.brandDeep);
      expect(AppColors.brandTint, AppBrand.canina.brandTint);
      expect(AppColors.brandTintSoft, AppBrand.canina.brandTintSoft);
      expect(AppColors.brandSurface, AppBrand.canina.brandSurface);
    });

    test('los colores de estado NO cambian con el tema (D-097)', () {
      // Es la regla que sostiene que el ambar signifique "pendiente" en todos
      // los negocios. Si un dia alguien mete un color de estado en
      // BrandPalette, esta prueba lo detiene.
      const pendienteAntes = AppColors.statePending;
      const porCobrarAntes = AppColors.stateToCollect;
      const peligroAntes = AppColors.danger;

      for (final palette in AppBrand.predefinidos) {
        AppBrand.aplicar(palette.key, null);

        expect(AppColors.statePending, pendienteAntes);
        expect(AppColors.stateToCollect, porCobrarAntes);
        expect(AppColors.danger, peligroAntes);
      }
    });

    test('cerrar sesion devuelve el morado de Salon y Mas', () {
      AppBrand.aplicar('barberia', null);
      expect(AppColors.brand, AppBrand.barberia.brand);

      AppBrand.aplicar(null, null);
      expect(AppColors.brand, AppBrand.morado.brand);
    });
  });
}
