import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Temas de marca blanca (D-093, D-100c, D-109).
///
/// Un tema son **seis colores**, no uno. La aplicacion necesita un tono fuerte
/// para la barra, uno oscuro para el boton presionado, uno casi negro para los
/// titulos y tres muy palidos para fondos y selecciones. Elegir solo el
/// primero y dejar los otros cinco en morado dejaria la pantalla a medias.
///
/// **Los colores de estado no estan aqui a proposito** (D-097): el ambar
/// significa "pendiente" en todos los negocios. Si el estado cambiara de color
/// con cada tema, dejaria de significar algo. Viven en [AppColors] y no se
/// tocan nunca.
///
/// **Regla de los dos colores** (D-109): los temas se describieron con dos
/// colores ("grafito y rojo", "celeste y dorado"), pero las seis casillas son
/// tonos de una sola familia. El primer color va en [brand] -- barra, botones
/// y selecciones -- y el segundo en [brandDeep] -- los titulos. El morado ya
/// funcionaba asi antes de que la regla existiera.
class BrandPalette {
  const BrandPalette({
    required this.key,
    required this.label,
    required this.description,
    required this.brand,
    required this.brandDark,
    required this.brandDeep,
    required this.brandTint,
    required this.brandTintSoft,
    required this.brandSurface,
  });

  /// Lo que se guarda en `tenants.theme_key`. Tiene que coincidir con la
  /// restriccion `tenants_theme_key_valido` de la base de datos.
  final String key;

  /// Como se llama en el selector de Configuracion.
  final String label;

  /// Para quien es. Lo lee un propietario, no un disenador.
  final String description;

  final Color brand;
  final Color brandDark;
  final Color brandDeep;
  final Color brandTint;
  final Color brandTintSoft;
  final Color brandSurface;
}

/// Catalogo de temas y tema activo.
class AppBrand {
  AppBrand._();

  /// Clave del tema que el propietario arma con su propio color.
  static const personalizadoKey = 'personalizado';

  /// Contraste minimo del texto blanco sobre la barra superior. 4.5:1 es el
  /// umbral AA de WCAG para texto normal. **No es decoracion:** buena parte de
  /// los clientes finales entra desde telefonos modestos y con sol encima.
  static const _contrasteMinimo = 4.5;

  /// El morado ratificado en D-097. Estos seis valores son exactamente los que
  /// tenia [AppColors] antes de que existiera la marca blanca: un negocio sin
  /// tema elegido no debe notar ningun cambio.
  static const morado = BrandPalette(
    key: 'morado',
    label: 'Morado',
    description: 'El de Salón y Más. Sirve para cualquier tipo de negocio.',
    brand: Color(0xFF7C3AED),
    brandDark: Color(0xFF6D28D9),
    brandDeep: Color(0xFF2D1B69),
    brandTint: Color(0xFFEDE9FE),
    brandTintSoft: Color(0xFFF5F3FF),
    brandSurface: Color(0xFFF8F5FF),
  );

  /// Grafito y rojo. El rojo vive **solo** en los titulos, nunca en la barra:
  /// una barra roja competiria con el rojo de "cancelado" y de eliminar, que
  /// es el choque que D-100d anticipo.
  static const barberia = BrandPalette(
    key: 'barberia',
    label: 'Barbería',
    description: 'Grafito y rojo. Sobrio, masculino, sin adornos.',
    brand: Color(0xFF3A3532),
    brandDark: Color(0xFF262220),
    brandDeep: Color(0xFF8E2B22),
    brandTint: Color(0xFFEFE3E0),
    brandTintSoft: Color(0xFFF8F2F0),
    brandSurface: Color(0xFFF7F5F3),
  );

  /// Celeste y dorado. El celeste esta mas oscuro de lo que pide el ojo porque
  /// a tono medio el texto blanco de la barra bajaba de 4.5:1.
  static const spaUnas = BrandPalette(
    key: 'spa_unas',
    label: 'Spa de uñas',
    description: 'Celeste y dorado. Limpio y tranquilo.',
    brand: Color(0xFF2F7B92),
    brandDark: Color(0xFF256274),
    brandDeep: Color(0xFF8A6520),
    brandTint: Color(0xFFDDEEF4),
    brandTintSoft: Color(0xFFF0F8FA),
    brandSurface: Color(0xFFF5FAFC),
  );

  /// Rosa y burdeos. El rosa quedo mas malva de lo que suena "rosa": el rosa
  /// claro no sostiene texto blanco encima.
  static const clasica = BrandPalette(
    key: 'clasica',
    label: 'Belleza clásica',
    description: 'Rosa y burdeos. Elegante, de peluquería de toda la vida.',
    brand: Color(0xFFA85B77),
    brandDark: Color(0xFF8E4A63),
    brandDeep: Color(0xFF6B1F3A),
    brandTint: Color(0xFFF7E3EA),
    brandTintSoft: Color(0xFFFCF2F5),
    brandSurface: Color(0xFFFDF6F8),
  );

  static const canina = BrandPalette(
    key: 'canina',
    label: 'Peluquería canina',
    description: 'Verde. Fresco y amable.',
    brand: Color(0xFF3F7A3C),
    brandDark: Color(0xFF2F5E2D),
    brandDeep: Color(0xFF1E4220),
    brandTint: Color(0xFFE0EFDE),
    brandTintSoft: Color(0xFFF1F8F0),
    brandSurface: Color(0xFFF5FAF4),
  );

  /// Los cinco verificados a mano, en el orden en que se muestran.
  static const predefinidos = <BrandPalette>[
    morado,
    barberia,
    spaUnas,
    clasica,
    canina,
  ];

  /// Color con el que arranca el selector personalizado si el negocio todavia
  /// no eligio ninguno.
  static const colorPersonalizadoPorDefecto = Color(0xFF2F6FB0);

  /// Los colores que se ofrecen en el tema personalizado.
  ///
  /// Es una rejilla y no una rueda de color por dos motivos: el propietario
  /// pidio "una paleta donde elegir", que es literalmente esto; y una rueda
  /// entrega tonos pastel ilegibles que luego hay que oscurecer, con lo que el
  /// color guardado no seria el que se toco. Todos estos ya se leen con texto
  /// blanco encima, asi que lo elegido es lo que se ve.
  static const coloresSugeridos = <Color>[
    Color(0xFFB4322E),
    Color(0xFFC2410C),
    Color(0xFFB45309),
    Color(0xFFA16207),
    Color(0xFF4D7C0F),
    Color(0xFF15803D),
    Color(0xFF0F766E),
    Color(0xFF0E7490),
    Color(0xFF0369A1),
    Color(0xFF1D4ED8),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF9333EA),
    Color(0xFFA21CAF),
    Color(0xFFBE185D),
    Color(0xFF9F1239),
    Color(0xFF57534E),
    Color(0xFF3A3532),
  ];

  /// Tema que la aplicacion esta pintando ahora mismo.
  ///
  /// Es un [ValueNotifier] y no una variable suelta porque `MaterialApp` tiene
  /// que reconstruirse cuando cambia: el tema se decide **despues** de arrancar
  /// la app, cuando llegan los datos del negocio.
  static final activo = ValueNotifier<BrandPalette>(morado);

  /// Aplica el tema de un negocio. Es lo unico que hay que llamar.
  ///
  /// Se llama desde tres sitios: al cargar el contexto de sede del panel, al
  /// abrir la pagina publica de reservas, y al cambiar el tema en
  /// Configuracion.
  static void aplicar(String? themeKey, String? brandColorHex) {
    final palette = resolver(themeKey, brandColorHex);

    if (identical(palette, activo.value)) {
      return;
    }

    // Se escriben aqui y no en AppColors para que `app_colors.dart` no tenga
    // que importar este archivo: la paleta conoce a los colores, no al reves.
    AppColors.brand = palette.brand;
    AppColors.brandDark = palette.brandDark;
    AppColors.brandDeep = palette.brandDeep;
    AppColors.brandTint = palette.brandTint;
    AppColors.brandTintSoft = palette.brandTintSoft;
    AppColors.brandSurface = palette.brandSurface;

    activo.value = palette;
  }

  /// Devuelve el tema que corresponde a lo guardado en la base de datos.
  ///
  /// Ante cualquier cosa rara -- clave desconocida, personalizado sin color,
  /// hex malformado -- devuelve el morado. Un negocio con un dato corrupto
  /// tiene que seguir pudiendo trabajar, no quedarse con una pantalla en
  /// blanco.
  static BrandPalette resolver(String? themeKey, String? brandColorHex) {
    final clave = themeKey?.trim().toLowerCase();

    if (clave == null || clave.isEmpty) {
      return morado;
    }

    if (clave == personalizadoKey) {
      final color = colorDesdeHex(brandColorHex);
      return color == null ? morado : derivar(color);
    }

    for (final palette in predefinidos) {
      if (palette.key == clave) {
        return palette;
      }
    }

    return morado;
  }

  /// Construye los seis tonos a partir del unico color que eligio el
  /// propietario (D-109).
  ///
  /// Lo importante no es la formula sino lo que garantiza: **el color elegido
  /// se oscurece hasta que el texto blanco de la barra se lea**. Sin eso, un
  /// amarillo o un celeste claro dejarian la barra superior ilegible y el
  /// propietario no tendria forma de saber por que.
  ///
  /// El segundo color -- el de los titulos -- sale del mismo tono, oscurecido.
  /// Los cinco temas de mano pueden combinar dos familias distintas ("grafito
  /// y rojo") porque un humano verifico que peguen; con un solo color elegido
  /// no hay de donde sacar el segundo sin adivinar.
  static BrandPalette derivar(Color elegido) {
    final base = oscurecerHastaLeerse(elegido);
    final hsl = HSLColor.fromColor(base);

    // Los fondos palidos bajan la saturacion: un tono muy saturado al 96 % de
    // luminosidad se ve fluorescente, no suave.
    HSLColor palido(double lightness, double factorSaturacion) {
      return hsl
          .withSaturation((hsl.saturation * factorSaturacion).clamp(0.0, 1.0))
          .withLightness(lightness);
    }

    return BrandPalette(
      key: personalizadoKey,
      label: 'Personalizado',
      description: 'Tu propio color.',
      brand: base,
      brandDark: hsl
          .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
          .toColor(),
      brandDeep: hsl
          .withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0))
          .withLightness(0.25)
          .toColor(),
      brandTint: palido(0.95, 1.0).toColor(),
      brandTintSoft: palido(0.965, 0.9).toColor(),
      brandSurface: palido(0.977, 0.8).toColor(),
    );
  }

  /// Baja la luminosidad del color hasta que el texto blanco encima alcance
  /// [_contrasteMinimo]. Si ya lo alcanza, lo devuelve intacto.
  static Color oscurecerHastaLeerse(Color elegido) {
    var hsl = HSLColor.fromColor(elegido);
    var pasos = 0;

    while (contrasteConBlanco(hsl.toColor()) < _contrasteMinimo &&
        hsl.lightness > 0.02 &&
        pasos < 60) {
      hsl = hsl.withLightness((hsl.lightness - 0.02).clamp(0.0, 1.0));
      pasos++;
    }

    return hsl.toColor();
  }

  /// Contraste del texto blanco sobre [fondo], segun WCAG 2.1.
  static double contrasteConBlanco(Color fondo) {
    return 1.05 / (luminanciaRelativa(fondo) + 0.05);
  }

  /// Contraste de [texto] sobre un fondo blanco. Sirve para los titulos, que
  /// van al reves que la barra: color oscuro sobre superficie clara.
  static double contrasteSobreBlanco(Color texto) {
    return 1.05 / (luminanciaRelativa(texto) + 0.05);
  }

  static double luminanciaRelativa(Color color) {
    double canal(double valor) {
      return valor <= 0.03928
          ? valor / 12.92
          : math.pow((valor + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * canal(color.r) +
        0.7152 * canal(color.g) +
        0.0722 * canal(color.b);
  }

  /// Lee un `#RRGGBB`. Devuelve null si no lo es -- misma validacion que la
  /// restriccion `tenants_brand_color_valido` de la base de datos.
  static Color? colorDesdeHex(String? hex) {
    final texto = hex?.trim().toUpperCase();

    if (texto == null || texto.length != 7 || !texto.startsWith('#')) {
      return null;
    }

    final valor = int.tryParse(texto.substring(1), radix: 16);
    return valor == null ? null : Color(0xFF000000 | valor);
  }

  /// Escribe un color como `#RRGGBB`, que es como lo espera la base de datos.
  static String hexDesdeColor(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);

    return '#'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}
