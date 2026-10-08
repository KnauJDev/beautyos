import 'package:flutter/material.dart';

import '../models/pagina_publica.dart' show duracionLegible;
import '../theme/app_theme.dart';

/// Elegir el servicio por cuadritos (D-322, pedido de David el 08-oct).
///
/// Con veintiocho servicios, una lista larga cansa. Al tocar el campo se abre
/// la pantalla entera con las **categorías en cuadritos**; se toca una, salen
/// **sus servicios**; se toca uno y **se cierra todo**, con ese servicio
/// elegido. Lo mismo en la reserva de la clienta y en Nueva cita del salón.
/// Prototipo aprobado: https://claude.ai/artifact/2NAFZNYbz3fqxwAX6H7qaQ
///
/// Las categorías son las que el salón escribe en cada servicio. Se juntan
/// sin mirar mayúsculas ("Peluquería" y "peluquería" son una), pero una tilde
/// de más o de menos es otra categoría: esas las corrige el salón.

/// Un servicio tal como se ofrece en el selector. Sirve igual para la
/// reserva en línea y para Nueva cita.
class ServicioParaElegir {
  const ServicioParaElegir({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.duracionMinutos,
    required this.precio,
  });

  final String id;
  final String nombre;

  /// Como la escribió el salón. Puede venir vacía.
  final String categoria;

  final int duracionMinutos;

  /// Ya con formato: `$25.000`.
  final String precio;

  String get detalle => '${duracionLegible(duracionMinutos)} · $precio';
}

/// Una categoría con sus servicios, ya ordenados por nombre.
typedef GrupoDeServicios = ({String nombre, List<ServicioParaElegir> servicios});

/// Adonde van los servicios que no tienen categoría.
const nombreDelGrupoSinCategoria = 'Otros';

/// Los modelos dicen "Sin categoria" cuando la base no trae ninguna.
bool _sinCategoria(String clave) =>
    clave.isEmpty || clave == 'sin categoria' || clave == 'sin categoría';

String _conMayuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Los servicios por categoría, en orden alfabético y con "Otros" al final.
List<GrupoDeServicios> agruparPorCategoria(List<ServicioParaElegir> servicios) {
  final nombres = <String, String>{};
  final grupos = <String, List<ServicioParaElegir>>{};
  for (final s in servicios) {
    final escrita = s.categoria.trim();
    final clave = escrita.toLowerCase();
    final llave = _sinCategoria(clave) ? '' : clave;
    nombres.putIfAbsent(
      llave,
      () => llave.isEmpty ? nombreDelGrupoSinCategoria : _conMayuscula(escrita),
    );
    grupos.putIfAbsent(llave, () => []).add(s);
  }

  final llaves = grupos.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      return a.compareTo(b);
    });

  return [
    for (final llave in llaves)
      (
        nombre: nombres[llave]!,
        servicios: [...grupos[llave]!]
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      ),
  ];
}

/// Abre la pantalla de los cuadritos. Devuelve el `id` del servicio elegido,
/// o `null` si se cerró sin elegir.
Future<String?> elegirServicioPorCuadritos(
  BuildContext context, {
  required List<ServicioParaElegir> servicios,
  String? elegidoId,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          PantallaDeElegirServicio(servicios: servicios, elegidoId: elegidoId),
    ),
  );
}

/// La pantalla entera: primero las categorías, después sus servicios. Si el
/// salón no usa categorías (o usa una sola), sale directo la lista.
class PantallaDeElegirServicio extends StatefulWidget {
  const PantallaDeElegirServicio({
    super.key,
    required this.servicios,
    this.elegidoId,
  });

  final List<ServicioParaElegir> servicios;
  final String? elegidoId;

  @override
  State<PantallaDeElegirServicio> createState() =>
      _PantallaDeElegirServicioState();
}

class _PantallaDeElegirServicioState extends State<PantallaDeElegirServicio> {
  late final List<GrupoDeServicios> _grupos = agruparPorCategoria(
    widget.servicios,
  );

  /// La categoría abierta. `null` = los cuadritos.
  GrupoDeServicios? _abierta;

  bool get _conCuadritos => _grupos.length >= 2;

  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    final List<ServicioParaElegir>? lista = !_conCuadritos
        ? [for (final g in _grupos) ...g.servicios]
        : abierta?.servicios;

    return PopScope(
      // El botón de atrás, dentro de una categoría, vuelve a los cuadritos.
      canPop: abierta == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _abierta = null);
      },
      child: Scaffold(
        backgroundColor: AppColors.brandSurface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: AppColors.border)),
          titleSpacing: abierta == null ? 16 : 4,
          leading: abierta == null
              ? null
              : IconButton(
                  tooltip: 'Volver a las categorías',
                  onPressed: () => setState(() => _abierta = null),
                  icon: const Icon(Icons.chevron_left),
                ),
          title: Text(
            abierta?.nombre ?? 'Elige un servicio',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: lista == null
                  ? _Cuadritos(
                      grupos: _grupos,
                      onAbrir: (g) => setState(() => _abierta = g),
                    )
                  : _Lista(
                      servicios: lista,
                      elegidoId: widget.elegidoId,
                      onElegir: (id) => Navigator.of(context).pop(id),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cuadritos extends StatelessWidget {
  const _Cuadritos({required this.grupos, required this.onAbrir});

  final List<GrupoDeServicios> grupos;
  final ValueChanged<GrupoDeServicios> onAbrir;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 140,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: grupos.length,
      itemBuilder: (context, i) {
        final g = grupos[i];
        final cuantos = g.servicios.length;
        final forma = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        );
        return Material(
          color: AppColors.surface,
          shape: forma,
          child: InkWell(
            customBorder: forma,
            onTap: () => onAbrir(g),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      g.nombre.characters.first.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Text(
                      g.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    cuantos == 1 ? '1 servicio' : '$cuantos servicios',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.servicios,
    required this.elegidoId,
    required this.onElegir,
  });

  final List<ServicioParaElegir> servicios;
  final String? elegidoId;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: servicios.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = servicios[i];
        final elegido = s.id == elegidoId;
        final forma = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: elegido ? AppColors.brand : AppColors.border,
            width: elegido ? 1.5 : 1,
          ),
        );
        return Material(
          color: AppColors.surface,
          shape: forma,
          child: InkWell(
            customBorder: forma,
            onTap: () => onElegir(s.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          duracionLegible(s.duracionMinutos),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.precio,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (elegido) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 20, color: AppColors.brand),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El campo que reemplaza la lista desplegable: dice qué servicio va
/// elegido y, al tocarlo, abre los cuadritos.
class CampoDeServicio extends StatelessWidget {
  const CampoDeServicio({
    super.key,
    required this.servicios,
    required this.elegidoId,
    required this.onElegido,
    this.decoracion = const InputDecoration(),
    this.errorText,
  });

  final List<ServicioParaElegir> servicios;
  final String? elegidoId;
  final ValueChanged<String> onElegido;
  final InputDecoration decoracion;
  final String? errorText;

  ServicioParaElegir? get _elegido {
    for (final s in servicios) {
      if (s.id == elegidoId) return s;
    }
    return null;
  }

  Future<void> _abrir(BuildContext context) async {
    final id = await elegirServicioPorCuadritos(
      context,
      servicios: servicios,
      elegidoId: elegidoId,
    );
    if (id != null) onElegido(id);
  }

  @override
  Widget build(BuildContext context) {
    final elegido = _elegido;
    final categoria = elegido?.categoria.trim() ?? '';
    final conCategoria =
        categoria.isNotEmpty && !_sinCategoria(categoria.toLowerCase());

    return InkWell(
      onTap: () => _abrir(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: elegido == null,
        decoration: decoracion.copyWith(
          hintText: decoracion.hintText ?? 'Toca para elegir',
          suffixIcon: const Icon(Icons.chevron_right),
          errorText: errorText,
        ),
        child: elegido == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    elegido.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    conCategoria
                        ? '${_conMayuscula(categoria)} · ${elegido.detalle}'
                        : elegido.detalle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
