import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Se muestra cuando ya hay sesion (correo+contraseña correctos) pero el
/// usuario tiene un factor TOTP verificado y la sesion todavia esta en
/// aal1 -- falta el segundo factor para llegar a aal2. Benchmarking
/// 2026-07-28 (AgendaPro), punto 3: 2FA opcional por usuario.
class MfaChallengePage extends StatefulWidget {
  const MfaChallengePage({super.key});

  @override
  State<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends State<MfaChallengePage> {
  final codeController = TextEditingController();
  bool isVerifying = false;
  bool isSigningOut = false;
  String? errorMessage;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      setState(() => errorMessage = 'Ingresa el código de 6 dígitos.');
      return;
    }

    setState(() {
      isVerifying = true;
      errorMessage = null;
    });

    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        setState(() {
          errorMessage = 'No se encontró un factor de verificación activo.';
        });
        return;
      }

      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: factors.totp.first.id,
        code: code,
      );
      // El propio SDK notifica AuthChangeEvent.mfaChallengeVerified;
      // AuthGate reacciona solo y muestra la app.
    } on AuthException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (_) {
      setState(() {
        errorMessage = 'Código incorrecto o vencido. Intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => isVerifying = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => isSigningOut = true);
    await Supabase.instance.client.auth.signOut();
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
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.brown.withValues(alpha: 0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.security_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Verificación en dos pasos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Abre tu app autenticadora e ingresa el código de 6 dígitos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verify(),
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: isVerifying ? null : _verify,
                        child: isVerifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verificar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isSigningOut ? null : _signOut,
                      child: Text(
                        isSigningOut
                            ? 'Cerrando sesión...'
                            : '¿Perdiste acceso a tu app? Cerrar sesión',
                      ),
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
