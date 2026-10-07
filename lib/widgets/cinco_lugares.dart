import 'package:flutter/material.dart';

import '../models/avisos_de_hoy.dart';
import '../models/lugares_de_la_app.dart';
import '../pages/settings_page.dart' show TuEnlaceCard;
import '../services/slug_del_salon_service.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Las piezas de pantalla de los cinco lugares (D-318): el menú (al lado en
/// el computador, abajo en el celular), el "← volver", la campana y las
/// puertas de *Mi vitrina* y *Ajustes*.
///
/// Ningún módulo cambia por dentro: estas piezas solo deciden **por dónde se
/// entra** a cada uno (D-219).

IconData iconoDeLugar(LugarDeLaApp lugar) {
  switch (lugar) {
    case LugarDeLaApp.agenda:
      return Icons.calendar_month_outlined;
    case LugarDeLaApp.clientes:
      return Icons.people_alt_outlined;
    case LugarDeLaApp.negocio:
      return Icons.insights_outlined;
    case LugarDeLaApp.vitrina:
      return Icons.storefront_outlined;
    case LugarDeLaApp.ajustes:
      return Icons.settings_outlined;
  }
}

/// El número rojo de un lugar: en la Agenda, las citas sin confirmar; en
/// Clientes, los que toca invitar hoy (D-304).
int globoDeLugar(LugarDeLaApp lugar, AvisosDeHoy? avisos) {
  if (avisos == null) return 0;
  switch (lugar) {
    case LugarDeLaApp.agenda:
      return avisos.sinConfirmar;
    case LugarDeLaApp.clientes:
      return avisos.paraInvitar;
    case LugarDeLaApp.negocio:
      return avisos.inventarioBajo;
    case LugarDeLaApp.vitrina:
    case LugarDeLaApp.ajustes:
      return 0;
  }
}

Widget _conGlobo(Widget icono, int n) =>
    n > 0 ? Badge(label: Text('$n'), child: icono) : icono;

/// El menú del computador: cinco renglones planos, sin categorías.
class MenuDeLugares extends StatelessWidget {
  const MenuDeLugares({
    super.key,
    required this.lugares,
    required this.actual,
    required this.onElegir,
    this.avisos,
  });

  final List<LugarDeLaApp> lugares;
  final LugarDeLaApp? actual;
  final ValueChanged<LugarDeLaApp> onElegir;
  final AvisosDeHoy? avisos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        children: [
          for (final l in lugares) ...[
            Material(
              color: l == actual ? AppColors.brandTintSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onElegir(l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        iconoDeLugar(l),
                        size: 21,
                        color: l == actual ? AppColors.brand : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.nombre,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: l == actual ? FontWeight.w800 : FontWeight.w600,
                            color: l == actual ? AppColors.brandDeep : AppColors.textStrong,
                          ),
                        ),
                      ),
                      if (globoDeLugar(l, avisos) > 0)
                        Badge(label: Text('${globoDeLugar(l, avisos)}')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// La barra del celular: los cinco lugares, sin *Más* (D-304). Cerrar sesión
/// y la seguridad de la cuenta viven en el círculo de arriba a la derecha.
class BarraDeLugares extends StatelessWidget {
  const BarraDeLugares({
    super.key,
    required this.lugares,
    required this.actual,
    required this.onElegir,
    this.avisos,
  });

  final List<LugarDeLaApp> lugares;
  final LugarDeLaApp? actual;
  final ValueChanged<LugarDeLaApp> onElegir;
  final AvisosDeHoy? avisos;

  @override
  Widget build(BuildContext context) {
    if (lugares.length < 2) return const SizedBox.shrink();
    final i = actual == null ? 0 : lugares.indexOf(actual!).clamp(0, lugares.length - 1);
    return NavigationBar(
      selectedIndex: i,
      elevation: 2,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brandTint,
      onDestinationSelected: (k) => onElegir(lugares[k]),
      destinations: [
        for (final l in lugares)
          NavigationDestination(
            icon: _conGlobo(Icon(iconoDeLugar(l), color: AppColors.textSecondary), globoDeLugar(l, avisos)),
            selectedIcon: _conGlobo(Icon(iconoDeLugar(l), color: AppColors.brand), globoDeLugar(l, avisos)),
            label: l.nombre,
          ),
      ],
    );
  }
}

/// "← Mi negocio": arriba de un módulo que se abrió desde su puerta.
class VolverAlLugar extends StatelessWidget {
  const VolverAlLugar({super.key, required this.lugar, required this.onVolver});

  final LugarDeLaApp lugar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onVolver,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(lugar.nombre),
          ),
        ),
      ),
    );
  }
}

/// La campana de arriba (D-304, construida con D-318).
class CampanaDeAvisos extends StatelessWidget {
  const CampanaDeAvisos({
    super.key,
    required this.avisos,
    required this.onAbrir,
    required this.onIr,
  });

  final AvisosDeHoy? avisos;

  /// Vuelve a cargar antes de mostrar la lista, para que no sea vieja.
  final Future<AvisosDeHoy> Function() onAbrir;
  final ValueChanged<AvisoDeLaCampana> onIr;

  @override
  Widget build(BuildContext context) {
    final n = avisos?.cuantos ?? 0;
    return IconButton(
      tooltip: 'Avisos',
      onPressed: () => _abrir(context),
      icon: _conGlobo(const Icon(Icons.notifications_outlined), n),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    final futuro = onAbrir();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (hoja) => SafeArea(
        child: FutureBuilder<AvisosDeHoy>(
          future: futuro,
          builder: (context, s) {
            final lista = (s.data ?? avisos ?? AvisosDeHoy.vacio).lista;
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                    'Lo que necesita tu atención hoy',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (s.connectionState == ConnectionState.waiting && s.data == null)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (lista.isEmpty)
                    const InfoPanel(
                      icon: Icons.check_circle_outline,
                      title: 'Nada pendiente',
                      description: 'No hay citas sin confirmar, clientes para invitar, inventario bajo ni sedes por vencer.',
                    )
                  else
                    for (final a in lista)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          size: 12,
                          color: a.urgente ? AppColors.danger : AppColors.warning,
                        ),
                        title: Text(a.texto),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(hoja).pop();
                          onIr(a);
                        },
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Un renglón de una puerta: abre un módulo de adentro.
class RenglonDePuerta {
  const RenglonDePuerta({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final VoidCallback onTap;
}

class RenglonesDePuerta extends StatelessWidget {
  const RenglonesDePuerta({super.key, required this.renglones});

  final List<RenglonDePuerta> renglones;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var k = 0; k < renglones.length; k++) ...[
            if (k > 0) Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: Icon(renglones[k].icono, color: AppColors.brand),
              title: Text(renglones[k].titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(renglones[k].descripcion),
              trailing: const Icon(Icons.chevron_right),
              onTap: renglones[k].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// La puerta de un lugar con varios módulos (*Ajustes*, y el pie de *Mi
/// negocio* con caja): su título y un renglón por módulo.
class PuertaDeLugarPage extends StatelessWidget {
  const PuertaDeLugarPage({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.renglones,
    this.encabezado,
  });

  final String titulo;
  final String subtitulo;
  final List<RenglonDePuerta> renglones;
  final Widget? encabezado;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: titulo,
      subtitle: subtitulo,
      children: [
        if (encabezado != null) ...[encabezado!, const SizedBox(height: AppSpacing.lg)],
        if (renglones.isNotEmpty) RenglonesDePuerta(renglones: renglones),
      ],
    );
  }
}

/// *Mi vitrina*: arriba, tu página y su enlace (el de D-313, con el nombre
/// del salón); debajo, Fotos, Reseñas y Blog.
class MiVitrinaPage extends StatefulWidget {
  const MiVitrinaPage({
    super.key,
    required this.branchId,
    required this.renglones,
    this.nombreDelSalon,
    this.citasNacenConfirmadas = false,
    this.esSedePrincipal = false,
  });

  final String branchId;
  final List<RenglonDePuerta> renglones;
  final String? nombreDelSalon;
  final bool citasNacenConfirmadas;
  final bool esSedePrincipal;

  @override
  State<MiVitrinaPage> createState() => _MiVitrinaPageState();
}

class _MiVitrinaPageState extends State<MiVitrinaPage> {
  late final Future<String?> _slug = const SlugDelSalonService().leer(widget.branchId);

  @override
  Widget build(BuildContext context) {
    return PuertaDeLugarPage(
      titulo: 'Mi vitrina',
      subtitulo: 'Lo que ven tus clientes.',
      encabezado: FutureBuilder<String?>(
        future: _slug,
        // La misma tarjeta de Configuración (D-318, 07-oct).
        builder: (context, s) => s.connectionState == ConnectionState.waiting
            ? const LoadingCard(mensaje: 'Cargando tu enlace...')
            : TuEnlaceCard(
                branchId: widget.branchId,
                slugDelSalon: s.data,
                nombreDelSalon: widget.nombreDelSalon,
                citasNacenConfirmadas: widget.citasNacenConfirmadas,
                esSedePrincipal: widget.esSedePrincipal,
              ),
      ),
      renglones: widget.renglones,
    );
  }
}
