import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/codigo_de_confirmacion.dart';
import '../models/mensaje_de_auth.dart';
import '../services/contrasena_service.dart';
import '../theme/app_theme.dart';

/// *¿Olvidaste tu contraseña?* (hallazgo CO, D-327).
///
/// Dos pasos: el correo y el código que llega. Con el código bueno se abre la
/// sesión y esta pantalla se cierra: [AuthGate] pide entonces la verificación
/// en dos pasos (si la cuenta la tiene) y después la contraseña nueva.
class RecuperarContrasenaPage extends StatefulWidget {
  const RecuperarContrasenaPage({
    super.key,
    this.correoInicial = '',
    this.servicio = const ContrasenaService(),
  });

  /// Lo que ya estaba escrito en la pantalla de entrar.
  final String correoInicial;
  final ContrasenaService servicio;

  @override
  State<RecuperarContrasenaPage> createState() =>
      _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  late final _correo = TextEditingController(text: widget.correoInicial.trim());
  final _codigo = TextEditingController();

  bool _pidiendoCodigo = false;
  bool _ocupado = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _mandarCodigo({bool otro = false}) async {
    final correo = _correo.text.trim();
    if (correo.isEmpty || !correo.contains('@')) {
      setState(() => _error = 'Escribe el correo con el que entras.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
      _aviso = null;
    });
    try {
      await widget.servicio.pedirCodigo(correo);
      if (!mounted) return;
      setState(() {
        _pidiendoCodigo = true;
        _codigo.clear();
        _aviso = otro
            ? 'Te mandamos uno nuevo. El anterior ya no sirve: usa el del '
                  'correo más reciente.'
            : null;
      });
    } on AuthException catch (error) {
      setState(() => _error = MensajeDeAuth.enEspanol(error));
    } catch (_) {
      setState(() => _error = 'No se pudo mandar el código. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _seguir() async {
    final codigo = CodigoDeConfirmacion.normalizar(_codigo.text);
    if (codigo == null) {
      setState(() => _error = CodigoDeConfirmacion.avisoDeFormato);
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
      _aviso = null;
    });
    try {
      await widget.servicio.entrarConCodigo(
        correo: _correo.text,
        codigo: codigo,
      );
      if (!mounted) return;
      // La sesión ya está abierta: al cerrar esta pantalla, AuthGate sigue.
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = MensajeDeAuth.enEspanol(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo revisar el código. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correo = _correo.text.trim();
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _pidiendoCodigo ? 'Escribe el código' : 'Recupera tu cuenta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pidiendoCodigo
                          ? 'Si $correo tiene cuenta, te llegó un código. '
                                'Caduca en una hora. Si no lo ves, mira en Spam.'
                          : 'Te mandamos un código a tu correo. Con él creas '
                                'una contraseña nueva.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (!_pidiendoCodigo)
                      TextField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Tu correo',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _mandarCodigo(),
                      )
                    else
                      TextField(
                        controller: _codigo,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Código del correo',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _seguir(),
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
                    if (_aviso != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _aviso!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _ocupado
                            ? null
                            : (_pidiendoCodigo ? _seguir : _mandarCodigo),
                        child: Text(
                          _ocupado
                              ? 'Un momento...'
                              : (_pidiendoCodigo ? 'Seguir' : 'Enviarme el código'),
                        ),
                      ),
                    ),
                    if (_pidiendoCodigo)
                      TextButton(
                        onPressed: _ocupado ? null : () => _mandarCodigo(otro: true),
                        child: const Text('No me llegó — pedir otro código'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Volver a ingresar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
