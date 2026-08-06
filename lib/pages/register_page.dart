import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  const RegisterPage({super.key, required this.onRegisterSuccess});

  final VoidCallback onRegisterSuccess;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? confirmationMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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

    setState(() {
      isLoading = true;
      errorMessage = null;
      confirmationMessage = null;
    });

    try {
      final signUpResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpResponse.session == null) {
        setState(() {
          confirmationMessage =
              'Te enviamos un correo de confirmación a $email. '
              'Confírmalo e inicia sesión para terminar de crear tu negocio.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.brown.withValues(alpha: 0.12)),
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
                        color: const Color(0xFF6D4C41),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.spa_outlined,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Crea tu cuenta en Salón y Más',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '21 días de prueba gratis, sin tarjeta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF795548)),
                    ),
                    const SizedBox(height: 24),
                    if (confirmationMessage != null) ...[
                      Text(
                        confirmationMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Volver a iniciar sesión'),
                      ),
                    ] else ...[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
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
                        decoration: const InputDecoration(
                          labelText: 'Contraseña (mínimo 8 caracteres)',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => register(),
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
                          label: Text(isLoading ? 'Creando...' : 'Continuar'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Ya tengo cuenta, iniciar sesión'),
                      ),
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
