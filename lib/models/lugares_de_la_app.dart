/// Los cinco lugares de la app (paso 6 del plan de David, D-318; D-219,
/// D-304).
///
/// **Ningún módulo se borra: cambia por dónde se entra.** Cada módulo de hoy
/// vive dentro de uno de los cinco lugares; el primero de cada lugar es su
/// puerta (la *Agenda*, *Clientes*, y las páginas de *Mi negocio*, *Mi
/// vitrina* y *Ajustes*). Lo demás se abre desde la puerta y trae un
/// "← volver" a ella.
///
/// Todo lo que se puede probar sin pantalla vive aquí: a qué lugar va cada
/// módulo, cuál es su puerta y qué lugares se ven.
library;

enum LugarDeLaApp {
  agenda('Agenda'),
  clientes('Clientes'),
  negocio('Mi negocio'),
  vitrina('Mi vitrina'),
  ajustes('Ajustes');

  const LugarDeLaApp(this.nombre);

  /// También es el título del módulo que hace de puerta del lugar.
  final String nombre;
}

/// A qué lugar va cada módulo, por su título (el mismo que usa `_irAModulo`).
/// Los de la estilista no están: su app tiene sus propios lugares (D-219).
const lugarDeCadaModulo = <String, LugarDeLaApp>{
  'Agenda': LugarDeLaApp.agenda,
  'Tickets & Caja': LugarDeLaApp.agenda,
  'Clientes': LugarDeLaApp.clientes,
  'Mi negocio': LugarDeLaApp.negocio,
  'Dashboard': LugarDeLaApp.negocio,
  'Reportes': LugarDeLaApp.negocio,
  'Inventario': LugarDeLaApp.negocio,
  'Compras': LugarDeLaApp.negocio,
  'Gastos': LugarDeLaApp.negocio,
  'Mi vitrina': LugarDeLaApp.vitrina,
  'Fotos de trabajos': LugarDeLaApp.vitrina,
  'Reseñas': LugarDeLaApp.vitrina,
  'Blog': LugarDeLaApp.vitrina,
  'Ajustes': LugarDeLaApp.ajustes,
  'Servicios': LugarDeLaApp.ajustes,
  'Estilistas': LugarDeLaApp.ajustes,
  'Usuarios': LugarDeLaApp.ajustes,
  'Configuración': LugarDeLaApp.ajustes,
};

LugarDeLaApp? lugarDe(String tituloDelModulo) =>
    lugarDeCadaModulo[tituloDelModulo];

/// La puerta del lugar: el módulo que se abre al tocarlo en el menú.
bool esPuerta(String tituloDelModulo) =>
    LugarDeLaApp.values.any((l) => l.nombre == tituloDelModulo);

/// Los lugares que se ven, en su orden, según los módulos que la persona
/// tiene: un lugar sin puerta no se enseña (la recepción, por ejemplo, no
/// tiene *Mi negocio* ni *Ajustes*).
List<LugarDeLaApp> lugaresVisibles(Iterable<String> titulosDeModulos) {
  final titulos = titulosDeModulos.toSet();
  return [
    for (final l in LugarDeLaApp.values)
      if (titulos.contains(l.nombre)) l,
  ];
}

/// Lo que va dentro de cada puerta con varios módulos, en el orden en que se
/// enseña. Solo aparece lo que el salón tiene (lo apagado no llega aquí).
const modulosDentroDe = <LugarDeLaApp, List<String>>{
  LugarDeLaApp.agenda: ['Tickets & Caja'],
  LugarDeLaApp.negocio: ['Reportes', 'Gastos', 'Compras', 'Inventario'],
  LugarDeLaApp.vitrina: ['Fotos de trabajos', 'Reseñas', 'Blog'],
  LugarDeLaApp.ajustes: ['Servicios', 'Estilistas', 'Usuarios', 'Configuración'],
};

/// Qué es cada módulo, en una línea, para los renglones de las puertas.
const descripcionDeModulo = <String, String>{
  'Tickets & Caja': 'Cobrar y la caja del día',
  'Dashboard': 'La historia de tu negocio, con sus gráficos',
  'Reportes': 'Ventas por servicio, por estilista y por método de pago',
  'Gastos': 'Arriendo, servicios, insumos',
  'Compras': 'Lo que le compras a tus proveedores',
  'Inventario': 'Tus productos y lo que se está acabando',
  'Fotos de trabajos': 'Las fotos que tus clientes autorizaron',
  'Reseñas': 'Lo que dicen de tu salón',
  'Blog': 'Los artículos de tu página',
  'Servicios': 'Tu catálogo, con precios y duración',
  'Estilistas': 'Tu equipo y lo que hace cada uno',
  'Usuarios': 'Quién entra a la app y qué puede hacer',
  'Configuración': 'Datos del salón, sedes, horarios, tema y más',
};
