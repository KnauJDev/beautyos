import 'package:flutter/material.dart';

import '../models/cuando_vuelve.dart';
import '../services/cuando_vuelve_service.dart';
import '../theme/app_theme.dart';

/// *Cuándo vuelve, por servicio*, en la ficha de la clienta (paso 9.63,
/// D-323). Cada servicio que se ha hecho, con su número y de dónde sale,
/// cuándo fue la última vez y cuándo le toca. *Cambiar* abre los mismos
/// atajos de la hoja de cierre; *Usar el del servicio* le quita su número.
/// Solo dueño, administrador y recepción: la estilista no ve Clientes.
class CuandoVuelveEnLaFicha extends StatefulWidget {
  const CuandoVuelveEnLaFicha({
    super.key,
    required this.servicio,
    required this.clientId,
    required this.nombre,
    this.ahora,
  });

  final CuandoVuelveService servicio;
  final String clientId;

  /// El primer nombre de la clienta, para los avisos.
  final String nombre;

  /// Las pruebas fijan la fecha.
  final DateTime? ahora;

  @override
  State<CuandoVuelveEnLaFicha> createState() => _CuandoVuelveEnLaFichaState();
}

class _CuandoVuelveEnLaFichaState extends State<CuandoVuelveEnLaFicha> {
  List<VueltaDeLaClienta>? _vueltas;
  String? _error;

  /// El servicio que se está cambiando y el número elegido.
  String? _editando;
  int _dias = 45;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final vueltas = await widget.servicio.deLaClienta(widget.clientId);
      if (!mounted) return;
      setState(() {
        _vueltas = vueltas;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar: $error');
    }
  }

  Future<void> _guardar(VueltaDeLaClienta v, int? dias) async {
    setState(() => _guardando = true);
    final avisos = ScaffoldMessenger.of(context);
    try {
      await widget.servicio.fijarDeLaClienta(
        clientId: widget.clientId,
        serviceId: v.serviceId,
        dias: dias,
      );
      await _cargar();
      if (!mounted) return;
      setState(() => _editando = null);
      final quien = widget.nombre.isEmpty ? 'La clienta' : widget.nombre;
      avisos.showSnackBar(
        SnackBar(
          content: Text(
            dias == null
                ? '$quien vuelve a usar el del servicio: ${v.diasSinElSuyo} días.'
                : 'Guardado: $quien vuelve a ${v.serviceName} cada $dias días.',
          ),
        ),
      );
    } catch (error) {
      avisos.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(fontSize: 13, color: AppColors.danger),
      );
    }
    final vueltas = _vueltas;
    if (vueltas == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (vueltas.isEmpty) {
      return const Text(
        'Todavía no se ha hecho ningún servicio. Cuando se cierre el primero, '
        'aquí sale cada cuánto vuelve.',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }
    final ahora = widget.ahora ?? DateTime.now();
    return Column(
      children: [
        for (var i = 0; i < vueltas.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          _fila(vueltas[i], ahora),
        ],
      ],
    );
  }

  Widget _fila(VueltaDeLaClienta v, DateTime ahora) {
    final editando = _editando == v.serviceId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.serviceName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    v.cadaCuanto,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: v.clientDays != null
                          ? AppColors.brandDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    v.cuando(ahora),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!editando)
              TextButton(
                onPressed: () => setState(() {
                  _editando = v.serviceId;
                  _dias = v.dias;
                }),
                child: const Text('Cambiar'),
              ),
          ],
        ),
        if (editando) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in opcionesDeDias)
                ChoiceChip(
                  label: Text('$o días'),
                  selected: _dias == o,
                  onSelected: (_) => setState(() => _dias = o),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Menos días',
                onPressed: _dias > 1 ? () => setState(() => _dias--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  '$_dias días',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Más días',
                onPressed: _dias < 365 ? () => setState(() => _dias++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (v.clientDays != null)
                TextButton(
                  onPressed: _guardando ? null : () => _guardar(v, null),
                  child: Text('Usar el del servicio (${v.diasSinElSuyo} días)'),
                ),
              TextButton(
                onPressed: _guardando
                    ? null
                    : () => setState(() => _editando = null),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _guardando ? null : () => _guardar(v, _dias),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
