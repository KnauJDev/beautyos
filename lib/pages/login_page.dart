import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aviso_de_enlace_de_correo.dart';
import '../theme/app_theme.dart';

import 'public_plans_page.dart';
import 'register_page.dart';
import 'terms_and_privacy_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
  });

  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  /// Hallazgo AM: si Supabase devolvió a esta persona con un error en la
  /// dirección, **se le dice**. Antes viajaba ahí sin que nadie lo leyera y
  /// la pantalla de acceso parecía normal.
  ///
  /// Se lee una sola vez al montar y no en `build`, porque el aviso se
  /// descarta al pulsar la X y un `build` posterior lo resucitaría.
  late final AvisoDeEnlaceDeCorreo? avisoDelEnlace =
      AvisoDeEnlaceDeCorreo.desdeLaDireccion(Uri.base);

  bool avisoDescartado = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Escribe correo y contraseña.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        setState(() {
          errorMessage = 'No se pudo iniciar sesión.';
        });
        return;
      }

      // Se le avisa al navegador que el login termino bien. Sin esto el
      // contexto de autocompletado queda abierto y el gestor de contrasenas
      // sigue preguntando si guardar mientras la persona trabaja (D-094).
      TextInput.finishAutofillContext();

      if (!mounted) {
        return;
      }

      widget.onLoginSuccess();
    } on AuthException catch (error) {
      setState(() {
        errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: const Icon(
                        Icons.spa_outlined,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Salón y Más',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa a tu cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (avisoDelEnlace != null && !avisoDescartado) ...[
                      _AvisoDelEnlace(
                        aviso: avisoDelEnlace!,
                        onCerrar: () =>
                            setState(() => avisoDescartado = true),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Los dos campos van juntos en un AutofillGroup y declaran
                    // que son (D-094). Sin esto el navegador ve una contrasena
                    // suelta, sin saber cual es el usuario, y ofrece guardarla
                    // con el nombre vacio y en momentos aleatorios.
                    AutofillGroup(
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => signIn(),
                          ),
                        ],
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : signIn,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_outlined),
                        label: Text(
                          isLoading ? 'Ingresando...' : 'Ingresar',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 18,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '¿Te invitaron a un equipo?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Inicia sesión con el correo de tu invitación si ya tienes contraseña.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: isLoading
                                ? null
                                : () async {
                                    final registered =
                                        await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => RegisterPage(
                                          isCollaborator: true,
                                          onRegisterSuccess: () {
                                            Navigator.of(context).pop(true);
                                          },
                                        ),
                                      ),
                                    );

                                    if (registered == true) {
                                      widget.onLoginSuccess();
                                    }
                                  },
                            child: Text(
                              '¿Primera vez? Crea tu contraseña de colaborador →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brand,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    const Text(
                      '¿Quieres usar Salón y Más en tu centro?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final registered = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => RegisterPage(
                                        onRegisterSuccess: () {
                                          Navigator.of(context).pop(true);
                                        },
                                      ),
                                    ),
                                  );

                              if (registered == true) {
                                widget.onLoginSuccess();
                              }
                            },
                      icon: const Icon(Icons.add_business_outlined, size: 18),
                      label: const Text('Registra tu negocio gratis'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandDeep,
                        side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PublicPlansPage(
                                    onLoginSuccess: widget.onLoginSuccess,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.sell_outlined, size: 16),
                      label: const Text('Ver planes y precios'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TermsAndPrivacyPage(initialTab: 0),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('Términos de Servicio'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TermsAndPrivacyPage(initialTab: 1),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Text('Política de Privacidad'),
                        ),
                      ],
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

/// El aviso de AM: qué pasó con el enlace del correo y **qué hacer ahora**.
///
/// Va en ámbar y no en rojo a propósito: casi siempre la cuenta sí quedó
/// confirmada y lo único que hace falta es iniciar sesión. Pintarlo de rojo
/// haría creer a alguien que ya está dentro que algo se rompió.
class _AvisoDelEnlace extends StatelessWidget {
  const _AvisoDelEnlace({required this.aviso, required this.onCerrar});

  final AvisoDeEnlaceDeCorreo aviso;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.link_off_outlined, size: 20,
              color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aviso.titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aviso.queHacer,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar aviso',
            onPressed: onCerrar,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
