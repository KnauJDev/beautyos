import 'package:flutter/material.dart';

import '../models/cuando_vuelve.dart';
import '../services/cuando_vuelve_service.dart';
import '../theme/app_theme.dart';

/// La hoja de *¿Cuándo invitamos a volver?* (paso 9.63, D-323).
///
/// Sale al cerrar la cita en la Agenda y al terminar un servicio en *Mi
/// agenda*, **ya llena**: el número de la clienta si ya tiene; si no, el del
/// servicio; si no, el del salón. Un toque en *Listo* y no demora el cierre.
/// Cada servicio trae su interruptor *Invitar a volver*: apagado, ese
/// servicio no la invita esta vez y su número no se borra.
/// Prototipo aprobado: https://claude.ai/artifact/N48aApd2qmN17Fxc5kHTne

/// Lo que se contestó de un servicio.
typedef RespuestaDeVuelta = ({VueltaAlCerrar vuelta, int dias, bool invitar});

/// Pregunta y guarda. **Nunca lanza**: la cita ya quedó cerrada, y si algo
/// falla aquí solo se avisa. `soloEstos` limita a esos servicios de la cita
/// (la estilista contesta el que acaba de terminar).
Future<void> preguntarCuandoVuelve(
  BuildContext context, {
  required CuandoVuelveService servicio,
  required String ticketId,
  required String nombreDeLaClienta,
  Set<String>? soloEstos,
  bool citaCerrada = false,
}) async {
  List<VueltaAlCerrar> vueltas;
  try {
    vueltas = await servicio.paraCerrar(ticketId);
  } catch (_) {
    return;
  }
  vueltas = [
    for (final v in vueltas)
      if (v.terminado &&
          (soloEstos == null || soloEstos.contains(v.ticketServiceId)))
        v,
  ];
  if (vueltas.isEmpty || !context.mounted) return;

  final hoy = DateTime.now();
  final respuestas = await showModalBottomSheet<List<RespuestaDeVuelta>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => HojaCuandoVuelve(
      vueltas: vueltas,
      nombre: primerNombre(nombreDeLaClienta),
      hoy: hoy,
      citaCerrada: citaCerrada,
    ),
  );
  if (respuestas == null || !context.mounted) return;

  final avisos = ScaffoldMessenger.of(context);
  try {
    for (final r in respuestas) {
      await servicio.guardarAlCerrar(
        ticketServiceId: r.vuelta.ticketServiceId,
        dias: r.invitar ? r.vuelta.diasParaGuardar(r.dias) : null,
        invitar: r.invitar,
      );
    }
    avisos
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            resumenDeLaVuelta(
              nombre: primerNombre(nombreDeLaClienta),
              respuestas: [
                for (final r in respuestas)
                  (servicio: r.vuelta.serviceName, dias: r.dias, invitar: r.invitar),
              ],
              hoy: hoy,
            ),
          ),
        ),
      );
  } catch (error) {
    avisos
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'La cita quedó cerrada, pero no se pudo guardar cuándo vuelve: $error',
          ),
        ),
      );
  }
}

class HojaCuandoVuelve extends StatefulWidget {
  const HojaCuandoVuelve({
    super.key,
    required this.vueltas,
    required this.nombre,
    required this.hoy,
    this.citaCerrada = false,
  });

  final List<VueltaAlCerrar> vueltas;

  /// El primer nombre de la clienta; vacío si no se sabe.
  final String nombre;
  final DateTime hoy;

  /// En la Agenda el título empieza por *Cita cerrada.*
  final bool citaCerrada;

  @override
  State<HojaCuandoVuelve> createState() => _HojaCuandoVuelveState();
}

class _HojaCuandoVuelveState extends State<HojaCuandoVuelve> {
  late final List<int> _dias = [for (final v in widget.vueltas) v.dias];
  late final List<bool> _invitar = [for (final _ in widget.vueltas) true];

  String get _titulo {
    final pregunta = widget.nombre.isEmpty
        ? '¿En cuántos días invitamos a volver?'
        : '¿Cuándo invitamos a ${widget.nombre} a volver?';
    return widget.citaCerrada ? 'Cita cerrada. $pregunta' : pregunta;
  }

  String get _explicacion => widget.nombre.isEmpty
      ? 'Ya viene lleno. Cámbialo solo si viene más seguido o más espaciado.'
      : 'Ya viene lleno. Cámbialo solo si ${widget.nombre} viene más seguido '
            'o más espaciado.';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _explicacion,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < widget.vueltas.length; i++) ...[
                _TarjetaDeVuelta(
                  vuelta: widget.vueltas[i],
                  nombre: widget.nombre,
                  hoy: widget.hoy,
                  dias: _dias[i],
                  invitar: _invitar[i],
                  onDias: (d) => setState(() => _dias[i] = d),
                  onInvitar: (v) => setState(() => _invitar[i] = v),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              FilledButton(
                onPressed: () => Navigator.of(context).pop([
                  for (var i = 0; i < widget.vueltas.length; i++)
                    (
                      vuelta: widget.vueltas[i],
                      dias: _dias[i],
                      invitar: _invitar[i],
                    ),
                ]),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _origen(VueltaAlCerrar v, String nombre) {
  switch (v.origen) {
    case OrigenDelNumero.suyo:
      return nombre.isEmpty ? 'El suyo' : 'El de $nombre';
    case OrigenDelNumero.delServicio:
      return 'El del servicio';
    case OrigenDelNumero.delSalon:
      return 'El del salón';
  }
}

class _TarjetaDeVuelta extends StatelessWidget {
  const _TarjetaDeVuelta({
    required this.vuelta,
    required this.nombre,
    required this.hoy,
    required this.dias,
    required this.invitar,
    required this.onDias,
    required this.onInvitar,
  });

  final VueltaAlCerrar vuelta;
  final String nombre;
  final DateTime hoy;
  final int dias;
  final bool invitar;
  final ValueChanged<int> onDias;
  final ValueChanged<bool> onInvitar;

  @override
  Widget build(BuildContext context) {
    final suyo = vuelta.origen == OrigenDelNumero.suyo;
    final quien = nombre.isEmpty ? 'esta persona' : nombre;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  vuelta.serviceName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: invitar ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: suyo ? AppColors.brandTint : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _origen(vuelta, nombre),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: suyo ? AppColors.brandDark : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invitar a volver',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: invitar, onChanged: onInvitar),
            ],
          ),
          if (invitar) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in opcionesDeDias)
                  ChoiceChip(
                    label: Text('$o días'),
                    selected: dias == o,
                    onSelected: (_) => onDias(o),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Menos días',
                  onPressed: dias > 1 ? () => onDias(dias - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    '$dias días',
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
                  onPressed: dias < 365 ? () => onDias(dias + 1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Le toca volver el ${fechaDeVolver(hoy, dias)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Esta vez no invitaremos a $quien por ${vuelta.serviceName}. '
                'Cuando vuelva a hacérselo, te preguntamos otra vez.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
