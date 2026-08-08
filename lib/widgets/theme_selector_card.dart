import 'package:flutter/material.dart';

import '../models/business_settings.dart';
import '../services/business_settings_service.dart';
import '../theme/app_theme.dart';
import 'app_states.dart';

/// Selector de tema de marca blanca (tarea 2.4, D-093, D-109).
///
/// Ofrece los cinco temas verificados a mano y, aparte, uno **personalizado**
/// donde el propietario elige un color y la aplicacion deriva los otros cinco
/// tonos. D-093 habia descartado elegir colores libremente; se reabrio porque
/// dos decisiones posteriores desactivaron el riesgo que lo motivaba: D-097
/// saco los colores de estado de la marca blanca y D-100d encerro el color de
/// marca en la barra, los titulos, los botones y las selecciones.
///
/// **Nada se aplica hasta que se guarda.** La vista previa se pinta con la
/// paleta derivada dentro de su propio recuadro: si el tema se aplicara al
/// tocarlo, un propietario que se arrepiente y cambia de pantalla dejaria la
/// aplicacion con colores que nunca guardo.
class ThemeSelectorCard extends StatefulWidget {
  const ThemeSelectorCard({
    super.key,
    required this.settings,
    required this.businessSettingsService,
    required this.onChanged,
  });

  final BusinessSettings settings;
  final BusinessSettingsService businessSettingsService;
  final VoidCallback onChanged;

  @override
  State<ThemeSelectorCard> createState() => _ThemeSelectorCardState();
}

class _ThemeSelectorCardState extends State<ThemeSelectorCard> {
  late String _seleccion;
  late Color _colorPersonalizado;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seleccion = _claveGuardada();
    _colorPersonalizado =
        AppBrand.colorDesdeHex(widget.settings.brandColor) ??
        AppBrand.colorPersonalizadoPorDefecto;
  }

  String _claveGuardada() {
    final guardada = widget.settings.themeKey?.trim().toLowerCase();

    if (guardada == AppBrand.personalizadoKey) {
      return AppBrand.personalizadoKey;
    }

    for (final palette in AppBrand.predefinidos) {
      if (palette.key == guardada) {
        return palette.key;
      }
    }

    return AppBrand.morado.key;
  }

  /// La paleta que se esta mostrando en la vista previa ahora mismo.
  BrandPalette get _previsualizada {
    if (_seleccion == AppBrand.personalizadoKey) {
      return AppBrand.derivar(_colorPersonalizado);
    }

    return AppBrand.resolver(_seleccion, null);
  }

  bool get _hayCambios {
    if (_seleccion != _claveGuardada()) return true;

    if (_seleccion == AppBrand.personalizadoKey) {
      final guardado = AppBrand.colorDesdeHex(widget.settings.brandColor);
      return guardado == null ||
          AppBrand.hexDesdeColor(guardado) !=
              AppBrand.hexDesdeColor(_colorPersonalizado);
    }

    return false;
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    final esPersonalizado = _seleccion == AppBrand.personalizadoKey;
    final hex = esPersonalizado
        ? AppBrand.hexDesdeColor(_colorPersonalizado)
        : null;

    try {
      await widget.businessSettingsService.updateTenantTheme(
        _seleccion,
        brandColorHex: hex,
      );

      // Recien aqui cambia la aplicacion entera: ya esta guardado, asi que lo
      // que se ve en pantalla y lo que hay en la base de datos coinciden.
      AppBrand.aplicar(_seleccion, hex);

      if (!mounted) return;
      widget.onChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tema guardado. Tambien cambio tu pagina publica de reservas.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo guardar el tema: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estos colores se ven en tu panel y tambien en el enlace de '
            'reservas que le pasas a tus clientes. Los colores de los estados '
            '(pendiente, confirmado, por cobrar) no cambian nunca: significan '
            'lo mismo en todos los negocios.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final palette in AppBrand.predefinidos)
                _OpcionTema(
                  titulo: palette.label,
                  detalle: palette.description,
                  muestraPrincipal: palette.brand,
                  muestraSecundaria: palette.brandDeep,
                  activa: _seleccion == palette.key,
                  onTap: _guardando
                      ? null
                      : () => setState(() => _seleccion = palette.key),
                ),
              _OpcionTema(
                titulo: 'Personalizado',
                detalle: 'Tu propio color.',
                muestraPrincipal: AppBrand.oscurecerHastaLeerse(
                  _colorPersonalizado,
                ),
                muestraSecundaria: AppBrand.derivar(
                  _colorPersonalizado,
                ).brandDeep,
                activa: _seleccion == AppBrand.personalizadoKey,
                onTap: _guardando
                    ? null
                    : () =>
                          setState(() => _seleccion = AppBrand.personalizadoKey),
              ),
            ],
          ),

          if (_seleccion == AppBrand.personalizadoKey) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Elige tu color',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final color in AppBrand.coloresSugeridos)
                  _MuestraColor(
                    color: color,
                    activa:
                        AppBrand.hexDesdeColor(color) ==
                        AppBrand.hexDesdeColor(_colorPersonalizado),
                    onTap: _guardando
                        ? null
                        : () => setState(() => _colorPersonalizado = color),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Asi se vera',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          _VistaPreviaTema(palette: _previsualizada),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              FilledButton.icon(
                onPressed: (_guardando || !_hayCambios) ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_guardando ? 'Guardando...' : 'Guardar tema'),
              ),
              if (!_hayCambios && !_guardando) ...[
                const SizedBox(width: AppSpacing.md),
                const Flexible(
                  child: Text(
                    'Es el tema que ya tienes.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Una opcion del selector: dos muestras de color, el nombre y para quien es.
class _OpcionTema extends StatelessWidget {
  const _OpcionTema({
    required this.titulo,
    required this.detalle,
    required this.muestraPrincipal,
    required this.muestraSecundaria,
    required this.activa,
    required this.onTap,
  });

  final String titulo;
  final String detalle;
  final Color muestraPrincipal;
  final Color muestraSecundaria;
  final bool activa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: activa ? muestraPrincipal : AppColors.border,
            width: activa ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _ParDeMuestras(
              principal: muestraPrincipal,
              secundaria: muestraSecundaria,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    detalle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (activa)
              Icon(Icons.check_circle, size: 18, color: muestraPrincipal),
          ],
        ),
      ),
    );
  }
}

/// El cuadro partido en dos que resume un tema: el color de la barra, y el de
/// los titulos en la esquina (D-109).
class _ParDeMuestras extends StatelessWidget {
  const _ParDeMuestras({required this.principal, required this.secundaria});

  final Color principal;
  final Color secundaria;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: principal,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: secundaria,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomRight: Radius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuestraColor extends StatelessWidget {
  const _MuestraColor({
    required this.color,
    required this.activa,
    required this.onTap,
  });

  final Color color;
  final bool activa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: activa ? AppColors.textPrimary : AppColors.border,
            width: activa ? 2 : 1,
          ),
        ),
        child: activa
            ? const Icon(Icons.check, size: 18, color: AppColors.textOnBrand)
            : null,
      ),
    );
  }
}

/// Un trozo de aplicacion de mentira pintado con la paleta que se esta
/// probando. **No lee el tema global a proposito:** el propietario tiene que
/// poder mirar un tema sin que la aplicacion entera cambie de color antes de
/// que el decida.
class _VistaPreviaTema extends StatelessWidget {
  const _VistaPreviaTema({required this.palette});

  final BrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: palette.brand,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: AppColors.textOnBrand,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Agenda',
                    style: TextStyle(
                      color: AppColors.textOnBrand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: palette.brandSurface,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Citas de hoy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.brandDeep,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // La tarjeta lleva la barra ambar de "solicitado" a
                  // proposito: demuestra en pantalla que los colores de estado
                  // NO cambian con el tema (D-097).
                  const AppCard(
                    accent: AppColors.statePending,
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '10:30 - Manicure',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        _PildoraSolicitado(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _BotonFalso(
                        texto: 'Confirmar',
                        fondo: palette.brand,
                        textoColor: AppColors.textOnBrand,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _BotonFalso(
                        texto: 'Clientes',
                        fondo: palette.brandTint,
                        textoColor: palette.brandDeep,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PildoraSolicitado extends StatelessWidget {
  const _PildoraSolicitado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.statePendingTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Solicitado',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.statePending,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BotonFalso extends StatelessWidget {
  const _BotonFalso({
    required this.texto,
    required this.fondo,
    required this.textoColor,
  });

  final String texto;
  final Color fondo;
  final Color textoColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: textoColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
