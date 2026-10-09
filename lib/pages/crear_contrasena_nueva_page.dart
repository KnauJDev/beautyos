import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contrasena_nueva.dart';
import '../models/mensaje_de_auth.dart';
import '../services/contrasena_service.dart';
import '../theme/app_theme.dart';

/// *Crea tu contraseña nueva*, después de entrar con el código de recuperar
/// (hallazgo CO, D-327). La enseña [AuthGate] mientras
/// [crearContrasenaNueva] esté encendido, y ya con la verificación en dos
/// pasos hecha si la cuenta la tiene.
class CrearContrasenaNuevaPage extends StatefulWidget {
  const CrearContrasenaNuevaPage({
    super.key,
    this.servicio = const ContrasenaService(),
    this.onSalir,
  });

  final ContrasenaService servicio;

  /// "Cerrar sesión": la salida si no quiere seguir. Por defecto cierra la
  /// sesión de Supabase.
  final Future<void> Function()? onSalir;

  @override
  State<CrearContrasenaNuevaPage> createState() =>
      _CrearContrasenaNuevaPageState();
}

class _CrearContrasenaNuevaPageState extends State<CrearContrasenaNuevaPage> {
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final aviso = ContrasenaNueva.aviso(_nueva.text, _repetida.text);
    if (aviso != null) {
      setState(() => _error = aviso);
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final avisos = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.servicio.cambiar(_nueva.text);
      avisos?.showSnackBar(
        const SnackBar(
          content: Text(
            'Listo: tu contraseña quedó cambiada. La próxima vez entras con la nueva.',
          ),
        ),
      );
      crearContrasenaNueva.value = false;
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = MensajeDeAuth.enEspanol(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo guardar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salir() async {
    crearContrasenaNueva.value = false;
    final salir = widget.onSalir;
    if (salir != null) {
      await salir();
    } else {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandSurface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Crea tu contraseña nueva',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDeep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mínimo ${ContrasenaNueva.minimo} caracteres. Con ella '
                        'entras la próxima vez.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _nueva,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Contraseña nueva',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _repetida,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Repítela',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _guardar(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _ocupado ? null : _guardar,
                          child: Text(_ocupado ? 'Guardando...' : 'Guardar y entrar'),
                        ),
                      ),
                      TextButton(
                        onPressed: _ocupado ? null : _salir,
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
