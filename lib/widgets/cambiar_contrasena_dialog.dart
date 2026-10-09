import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/codigo_de_confirmacion.dart';
import '../models/contrasena_nueva.dart';
import '../models/mensaje_de_auth.dart';
import '../services/contrasena_service.dart';

/// *Cambiar contraseña*, desde *Seguridad de tu cuenta* (hallazgo CO, D-327).
///
/// Se escribe la nueva dos veces. Si la sesión es de hace más de un día,
/// Supabase pide antes un código al correo (`reauthentication_needed`): la
/// ventana lo manda sola y pide el código, sin perder lo escrito.
/// Devuelve `true` si la contraseña quedó cambiada.
class CambiarContrasenaDialog extends StatefulWidget {
  const CambiarContrasenaDialog({
    super.key,
    this.servicio = const ContrasenaService(),
  });

  final ContrasenaService servicio;

  @override
  State<CambiarContrasenaDialog> createState() =>
      _CambiarContrasenaDialogState();
}

class _CambiarContrasenaDialogState extends State<CambiarContrasenaDialog> {
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  final _codigo = TextEditingController();

  /// Supabase pidió confirmar con el código del correo.
  bool _pideCodigo = false;
  bool _ocupado = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _nueva.dispose();
    _repetida.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _mandarCodigo({bool otro = false}) async {
    try {
      await widget.servicio.pedirCodigoDeSeguridad();
      if (!mounted) return;
      setState(() {
        _pideCodigo = true;
        _codigo.clear();
        _aviso = otro
            ? 'Te mandamos uno nuevo. El anterior ya no sirve.'
            : 'Por seguridad te mandamos un código a tu correo. Escríbelo '
                  'para guardar la contraseña.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = MensajeDeAuth.enEspanol(error));
    }
  }

  Future<void> _guardar() async {
    final aviso = ContrasenaNueva.aviso(_nueva.text, _repetida.text);
    if (aviso != null) {
      setState(() => _error = aviso);
      return;
    }
    String? codigo;
    if (_pideCodigo) {
      codigo = CodigoDeConfirmacion.normalizar(_codigo.text);
      if (codigo == null) {
        setState(() => _error = CodigoDeConfirmacion.avisoDeFormato);
        return;
      }
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.servicio.cambiar(_nueva.text, codigo: codigo);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'reauthentication_needed') {
        await _mandarCodigo();
        return;
      }
      setState(() => _error = MensajeDeAuth.enEspanol(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo guardar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nueva,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Contraseña nueva',
                  helperText: 'Mínimo ${ContrasenaNueva.minimo} caracteres.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repetida,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Repítela'),
                onSubmitted: (_) => _guardar(),
              ),
              if (_pideCodigo) ...[
                const SizedBox(height: 16),
                if (_aviso != null)
                  Text(
                    _aviso!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codigo,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Código del correo',
                  ),
                  onSubmitted: (_) => _guardar(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _ocupado ? null : () => _mandarCodigo(otro: true),
                    child: const Text('No me llegó — pedir otro código'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: Text(_ocupado ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}
