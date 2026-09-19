import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/codigo_de_confirmacion.dart';
import '../theme/app_theme.dart';
import 'public_plans_page.dart';
import 'terms_and_privacy_page.dart';

/// Crea únicamente el acceso (correo/contraseña) en Supabase Auth. Los
/// datos del negocio se piden aparte, en CompleteTenantSetupPage, una vez
/// exista una sesión real y estable.
///
/// A propósito no llama a register_tenant() aquí: AuthGate reacciona al
/// nuevo estado de sesión tan pronto como signUp() la crea, y reemplaza
/// este widget antes de que una llamada adicional en la misma pantalla
/// alcance a completarse. Al dejar que sea la pantalla siguiente (ya
/// montada de forma estable) la que registre el negocio, se evita esa
/// condición de carrera.
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.onRegisterSuccess,
    this.isCollaborator = false,
  });

  final VoidCallback onRegisterSuccess;
  final bool isCollaborator;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool acceptedTerms = false;
  String? errorMessage;

  // --- Confirmación por código de 6 dígitos (hallazgo AH, 18-sep) ----------
  //
  // **Por qué ya no hay enlace.** El correo de confirmación traía un enlace de
  // un solo uso, y los escáneres antifraude del buzón lo visitan antes que la
  // persona: cuando ella pulsaba, el enlace ya estaba gastado. Verificado el
  // 18-sep — enviado 12:38, pulsado 12:40, `otp_expired`, y la cuenta
  // confirmada igual. **Subir el plazo de caducidad no arreglaba nada**, que
  // era lo que decía el enunciado viejo de AH.
  //
  // Un código de seis dígitos no se puede gastar visitándolo: no hay nada que
  // visitar. Y de paso funciona aunque el correo se abra en otro navegador o
  // en otro teléfono, cosa que el enlace con PKCE no hacía.
  final codeController = TextEditingController();

  /// El correo con el que se creó la cuenta. `verifyOTP` lo necesita junto al
  /// código, y no se puede confiar en que el campo siga intacto.
  String? correoPendienteDeConfirmar;

  bool confirmandoCodigo = false;
  bool reenviandoCodigo = false;
  String? mensajeDelCodigo;

  late final _termsTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegal(context, 0);
  late final _privacyTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegal(context, 1);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    codeController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  /// Confirma la cuenta con el código de seis dígitos que llegó por correo.
  ///
  /// **Todo error se queda en esta pantalla** y no borra lo escrito: es la
  /// lección del hallazgo AK, donde cuatro diálogos validaban después de
  /// cerrarse y tiraban el trabajo de la persona.
  Future<void> confirmarCodigo() async {
    // La longitud del código la decide Supabase, no esta pantalla: aquí solo
    // se limpia y se comprueba que sea plausible (ver `CodigoDeConfirmacion`).
    final codigo = CodigoDeConfirmacion.normalizar(codeController.text);
    final correo = correoPendienteDeConfirmar;

    if (codigo == null) {
      setState(() => errorMessage = CodigoDeConfirmacion.avisoDeFormato);
      return;
    }

    if (correo == null) {
      setState(() => errorMessage = 'Vuelve a empezar el registro.');
      return;
    }

    setState(() {
      confirmandoCodigo = true;
      errorMessage = null;
      mensajeDelCodigo = null;
    });

    try {
      final respuesta = await Supabase.instance.client.auth.verifyOTP(
        email: correo,
        token: codigo,
        type: OtpType.signup,
      );

      if (respuesta.session == null) {
        setState(() => errorMessage = 'Ese código no sirvió. Pide otro.');
        return;
      }

      if (!mounted) return;
      widget.onRegisterSuccess();
    } on AuthException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (_) {
      setState(() => errorMessage = 'No se pudo confirmar el código.');
    } finally {
      if (mounted) {
        setState(() => confirmandoCodigo = false);
      }
    }
  }

  /// Vuelve a enviar el código. Existe porque un código caduca y un correo se
  /// pierde, y sin esto la única salida sería registrarse otra vez.
  Future<void> reenviarCodigo() async {
    final correo = correoPendienteDeConfirmar;
    if (correo == null) return;

    setState(() {
      reenviandoCodigo = true;
      errorMessage = null;
      mensajeDelCodigo = null;
    });

    try {
      await Supabase.instance.client.auth.resend(
        email: correo,
        type: OtpType.signup,
      );

      setState(() => mensajeDelCodigo = 'Te enviamos un código nuevo.');
    } on AuthException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (_) {
      setState(() => errorMessage = 'No se pudo reenviar el código.');
    } finally {
      if (mounted) {
        setState(() => reenviandoCodigo = false);
      }
    }
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Escribe correo y contraseña.';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      });
      return;
    }

    if (!acceptedTerms) {
      setState(() {
        errorMessage =
            'Debes aceptar los Términos de Servicio y la Política de '
            'Privacidad para continuar.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      mensajeDelCodigo = null;
    });

    try {
      final signUpResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpResponse.session == null) {
        // La cuenta existe pero falta confirmar el correo. En vez de mandar a
        // la persona fuera de la aplicación a buscar un enlace —que llegaba
        // gastado, hallazgo AH—, se le pide aquí mismo el código.
        setState(() {
          correoPendienteDeConfirmar = email;
          codeController.clear();
        });
        return;
      }

      if (!mounted) {
        return;
      }

      widget.onRegisterSuccess();
    } on AuthException catch (error) {
      setState(() {
        errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        errorMessage = 'Ocurrió un error inesperado al registrarte.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _openLegal(BuildContext context, int initialTab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermsAndPrivacyPage(initialTab: initialTab),
      ),
    );
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
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
                      widget.isCollaborator
                          ? 'Crea tu cuenta de colaborador'
                          : 'Registra tu negocio en Salón y Más',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isCollaborator
                          ? 'Ingresa el correo al que te llegó la invitación y define tu contraseña.'
                          : '21 días de prueba gratis, sin tarjeta.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (correoPendienteDeConfirmar != null) ...[
                      Text(
                        'Te enviamos un código a\n'
                        '$correoPendienteDeConfirmar',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Escríbelo aquí abajo. Si no lo ves, mira en Promociones '
                        'o en el correo no deseado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        // Sin `maxLength` a propósito: el 19-sep llegó un
                        // código de **ocho** dígitos y un tope de 6 le
                        // cortaba dos. La longitud vive en Supabase.
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Código del correo',
                          // El campo escribe grande y muy espaciado para que
                          // el código se lea de un vistazo; la pista no, o
                          // saldría desparramada y sin caber.
                          hintStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => confirmarCodigo(),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (mensajeDelCodigo != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          mensajeDelCodigo!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: confirmandoCodigo ? null : confirmarCodigo,
                          icon: confirmandoCodigo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            confirmandoCodigo
                                ? 'Confirmando...'
                                : 'Confirmar mi correo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: reenviandoCodigo ? null : reenviarCodigo,
                        child: Text(
                          reenviandoCodigo
                              ? 'Enviando...'
                              : 'No me llegó — enviar otro código',
                        ),
                      ),
                    ] else ...[
                      // Mismo criterio que en el login (D-094): los dos campos
                      // declaran que son, para que el gestor de contrasenas
                      // guarde bien y no pregunte a destiempo.
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
                                AutofillHints.newPassword,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Contraseña (mínimo 8 caracteres)',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => register(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: acceptedTerms,
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      acceptedTerms = value ?? false;
                                    });
                                  },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Acepto los '),
                                    TextSpan(
                                      text: 'Términos de Servicio',
                                      style: TextStyle(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      recognizer: _termsTapRecognizer,
                                    ),
                                    const TextSpan(text: ' y la '),
                                    TextSpan(
                                      text: 'Política de Privacidad',
                                      style: TextStyle(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      recognizer: _privacyTapRecognizer,
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
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
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : register,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.rocket_launch_outlined),
                          label: Text(
                            isLoading
                                ? 'Creando...'
                                : widget.isCollaborator
                                    ? 'Crear mi cuenta'
                                    : 'Continuar',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          widget.isCollaborator
                              ? '¿Ya tienes contraseña? Inicia sesión'
                              : '¿Ya tienes cuenta o te invitaron a un equipo? Inicia sesión',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (!widget.isCollaborator) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const PublicPlansPage(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Ver qué incluye cada plan'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ],
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
