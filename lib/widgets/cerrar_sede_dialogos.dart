import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cerrar_sede.dart';
import '../services/cerrar_sede_service.dart';
import '../theme/app_theme.dart';

/// Las ventanas de *Cerrar sede* y *Volver a abrir* (paso 9.65, D-328). Las
/// mismas en el Panel de la plataforma y en Configuración del salón.
/// Prototipo aprobado: https://claude.ai/artifact/FKNnRij9kGtaNWPknX6HZB

/// Pregunta y cierra. Si la sede tiene citas próximas, **no deja**: dice
/// cuáles son, para moverlas o cancelarlas primero. Devuelve `true` si quedó
/// cerrada.
Future<bool> cerrarSedeConCuidado(
  BuildContext context, {
  required CerrarSedeService servicio,
  required String branchId,
  required String nombre,
}) async {
  final avisos = ScaffoldMessenger.of(context);
  List<CitaProxima> citas;
  try {
    citas = await servicio.proximasCitas(branchId);
  } catch (error) {
    avisos.showSnackBar(
      SnackBar(content: Text('No se pudieron revisar las citas de la sede: ${_mensaje(error)}')),
    );
    return false;
  }
  if (!context.mounted) return false;

  if (citas.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (_) => DialogoSedeConCitas(nombre: nombre, citas: citas),
    );
    return false;
  }

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (_) => DialogoCerrarSede(nombre: nombre),
  );
  if (confirmado != true) return false;

  try {
    await servicio.cerrar(branchId);
  } catch (error) {
    avisos.showSnackBar(SnackBar(content: Text('No se pudo cerrar: ${_mensaje(error)}')));
    return false;
  }
  avisos.showSnackBar(
    SnackBar(content: Text('$nombre quedó cerrada. Su historial se conserva.')),
  );
  return true;
}

/// Pregunta y la vuelve a abrir. Devuelve `true` si quedó abierta.
Future<bool> reabrirSede(
  BuildContext context, {
  required CerrarSedeService servicio,
  required String branchId,
  required String nombre,
}) async {
  final avisos = ScaffoldMessenger.of(context);
  final plataforma = servicio.desdeLaPlataforma;
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Volver a abrir $nombre?'),
      content: SizedBox(
        width: 420,
        child: Text(
          plataforma
              ? 'Vuelve a verse, a recibir citas y queda activa. Si hace falta, '
                    'cámbiale después el estado de pago.'
              : 'Vuelve a verse y a recibir citas. Queda pendiente de pago, como '
                    'una sede nueva.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Volver a abrir'),
        ),
      ],
    ),
  );
  if (confirmado != true) return false;

  try {
    await servicio.reabrir(branchId);
  } catch (error) {
    avisos.showSnackBar(SnackBar(content: Text('No se pudo abrir: ${_mensaje(error)}')));
    return false;
  }
  avisos.showSnackBar(
    SnackBar(
      content: Text(
        plataforma
            ? '$nombre abierta otra vez, activa.'
            : '$nombre abierta otra vez. Queda pendiente de pago, como una sede nueva.',
      ),
    ),
  );
  return true;
}

String _mensaje(Object error) =>
    error is PostgrestException ? error.message : error.toString();

/// "Así no se puede cerrar": las citas que hay que mover o cancelar.
class DialogoSedeConCitas extends StatelessWidget {
  const DialogoSedeConCitas({super.key, required this.nombre, required this.citas});

  final String nombre;
  final List<CitaProxima> citas;

  @override
  Widget build(BuildContext context) {
    final cuantas = citas.length == 1 ? '1 cita próxima' : '${citas.length} citas próximas';
    return AlertDialog(
      title: Text('$nombre tiene $cuantas'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Así no se puede cerrar: esas clientas llegarían a una sede cerrada.',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              for (final c in citas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${c.texto}', style: const TextStyle(fontSize: 13)),
                ),
              const SizedBox(height: 8),
              const Text('Muévelas a otra sede o cancélalas primero, y vuelve a intentarlo.'),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}

/// "¿Cerrar la sede?", con lo que pasa y lo que se conserva.
class DialogoCerrarSede extends StatelessWidget {
  const DialogoCerrarSede({super.key, required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('¿Cerrar $nombre?'),
      content: const SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deja de verse en la app, en la reserva en línea y en la página. '
              'No recibe citas nuevas y no se cobra.',
            ),
            SizedBox(height: 10),
            Text('• Sus citas pasadas, ventas, comisiones y pagos se conservan y siguen en los reportes.'),
            SizedBox(height: 4),
            Text('• Las clientas son del negocio: siguen en las otras sedes.'),
            SizedBox(height: 4),
            Text('• Se puede volver a abrir cuando quieras.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cerrar sede'),
        ),
      ],
    );
  }
}
