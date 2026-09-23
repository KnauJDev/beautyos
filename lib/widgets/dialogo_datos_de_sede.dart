import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Los siete datos propios de una sede (D-241).
class DatosDeSede {
  const DatosDeSede({
    this.managerName,
    this.contactEmail,
    this.contactPhone,
    this.whatsapp,
    this.address,
    this.city,
    this.department,
  });

  final String? managerName;
  final String? contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? department;
}

/// Edita los datos propios de una sede y **guarda desde dentro** (hallazgo AK).
///
/// **Por qué existe.** Este formulario estaba escrito dos veces, casi letra por
/// letra: en el Panel de plataforma (D-241) y en la Configuración del salón
/// (D-242). Las dos copias hacían lo mismo mal: se cerraban, *después* llamaban
/// al servidor, y si rechazaba el aviso salía abajo con los siete campos
/// perdidos. Es exactamente lo que vivió el propietario el 17-sep al poner un
/// correo sin arroba: *"me salió error abajo casi imperceptible y al parecer
/// me sacó sin guardar... para mí me daría jartera y no volvería a usarlo"*.
///
/// Ahora hay una sola, y si el servidor rechaza **se queda abierta, con todo
/// escrito, y el error junto al campo que lo causó**. Es el patrón de D-249
/// (Clientes). Devuelve `true` si guardó.
///
/// [guardar] recibe los datos ya limpios (vacío = null) y es quien llama al
/// servidor: cada pantalla usa su propio servicio.
Future<bool> mostrarDialogoDatosDeSede(
  BuildContext context, {
  required String nombreSede,
  required String aviso,
  required DatosDeSede actuales,
  required Future<void> Function(DatosDeSede datos) guardar,
}) async {
  final guardado = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoDatosDeSede(
      nombreSede: nombreSede,
      aviso: aviso,
      actuales: actuales,
      guardar: guardar,
    ),
  );
  return guardado == true;
}

class _DialogoDatosDeSede extends StatefulWidget {
  const _DialogoDatosDeSede({
    required this.nombreSede,
    required this.aviso,
    required this.actuales,
    required this.guardar,
  });

  final String nombreSede;
  final String aviso;
  final DatosDeSede actuales;
  final Future<void> Function(DatosDeSede datos) guardar;

  @override
  State<_DialogoDatosDeSede> createState() => _DialogoDatosDeSedeState();
}

class _DialogoDatosDeSedeState extends State<_DialogoDatosDeSede> {
  late final _encargado = TextEditingController(
    text: widget.actuales.managerName ?? '',
  );
  late final _correo = TextEditingController(
    text: widget.actuales.contactEmail ?? '',
  );
  late final _telefono = TextEditingController(
    text: widget.actuales.contactPhone ?? '',
  );
  late final _whatsapp = TextEditingController(
    text: widget.actuales.whatsapp ?? '',
  );
  late final _direccion = TextEditingController(
    text: widget.actuales.address ?? '',
  );
  late final _ciudad = TextEditingController(text: widget.actuales.city ?? '');
  late final _departamento = TextEditingController(
    text: widget.actuales.department ?? '',
  );

  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [
      _encargado,
      _correo,
      _telefono,
      _whatsapp,
      _direccion,
      _ciudad,
      _departamento,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _limpio(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// A qué campo pertenece el rechazo, por lo que dice el servidor. Si no se
  /// reconoce, el error va debajo de todos: nunca se pierde.
  TextEditingController? _campoDelError(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('correo') || m.contains('arroba') || m.contains('email')) {
      return _correo;
    }
    if (m.contains('whatsapp')) return _whatsapp;
    if (m.contains('teléfono') || m.contains('telefono')) return _telefono;
    return null;
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.guardar(
        DatosDeSede(
          managerName: _limpio(_encargado),
          contactEmail: _limpio(_correo),
          contactPhone: _limpio(_telefono),
          whatsapp: _limpio(_whatsapp),
          address: _limpio(_direccion),
          city: _limpio(_ciudad),
          department: _limpio(_departamento),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      // El mensaje viene del servidor, que es quien sabe qué regla se
      // incumplió: por ejemplo, un correo sin arroba.
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar. Revisa tu conexión e inténtalo otra vez: '
            'lo que escribiste sigue aquí.';
      });
    }
  }

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    String? ayuda,
    TextInputType? teclado,
  }) {
    final error = _error != null && _campoDelError(_error!) == c
        ? _error
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: teclado,
        enabled: !_guardando,
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          helperMaxLines: 2,
          errorText: error,
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorSuelto = _error != null && _campoDelError(_error!) == null;

    return AlertDialog(
      title: Text('Datos de ${widget.nombreSede}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.aviso,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _campo(
                _encargado,
                'Encargado de la sede',
                ayuda: 'Quien la lleva. Puede no ser el dueño del negocio.',
              ),
              _campo(
                _correo,
                'Correo de la sede',
                teclado: TextInputType.emailAddress,
                ayuda: 'Si lo pones, tiene que llevar arroba.',
              ),
              _campo(_telefono, 'Teléfono', teclado: TextInputType.phone),
              _campo(_whatsapp, 'WhatsApp', teclado: TextInputType.phone),
              _campo(_direccion, 'Dirección'),
              _campo(_ciudad, 'Ciudad'),
              _campo(_departamento, 'Departamento'),
              if (errorSuelto)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
