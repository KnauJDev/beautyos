import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_version_service.dart';
import 'update_banner.dart';

/// Activar/desactivar verificacion en dos pasos (TOTP) para el usuario
/// actual. Benchmarking 2026-07-28 (AgendaPro), punto 3: opcional, cada
/// quien lo activa desde su propia cuenta -- nadie queda obligado ni
/// bloqueado por accidente mientras se prueba.
class SecuritySettingsDialog extends StatefulWidget {
  const SecuritySettingsDialog({super.key});

  @override
  State<SecuritySettingsDialog> createState() =>
      _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends State<SecuritySettingsDialog> {
  late Future<List<Factor>> factorsFuture;

  // Estado del flujo de activacion en curso (null = no se ha empezado).
  String? _pendingFactorId;
  String? _pendingQrCode;
  String? _pendingSecret;
  final _codeController = TextEditingController();

  bool isBusy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    factorsFuture = _loadFactors();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<List<Factor>> _loadFactors() async {
    final result = await Supabase.instance.client.auth.mfa.listFactors();
    return result.totp;
  }

  void _reload() {
    setState(() {
      factorsFuture = _loadFactors();
      _pendingFactorId = null;
      _pendingQrCode = null;
      _pendingSecret = null;
      _codeController.clear();
      error = null;
    });
  }

  Future<void> _startEnroll() async {
    setState(() {
      isBusy = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.mfa.enroll(
        factorType: FactorType.totp,
        // Nombre que la persona ve en su app de autenticacion (Google
        // Authenticator y similares). Solo aplica a inscripciones nuevas: a
        // quien ya tenga el 2FA activo le sigue apareciendo el nombre viejo,
        // y eso no rompe nada porque el emisor es solo una etiqueta.
        issuer: 'Salón y Más',
        friendlyName: 'App autenticadora',
      );

      setState(() {
        _pendingFactorId = response.id;
        _pendingQrCode = response.totp?.qrCode.replaceFirst(
          'data:image/svg+xml;utf-8,',
          '',
        );
        _pendingSecret = response.totp?.secret;
      });
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'No se pudo iniciar la activación: $e');
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  Future<void> _confirmEnroll() async {
    final factorId = _pendingFactorId;
    final code = _codeController.text.trim();

    if (factorId == null) return;
    if (code.length != 6) {
      setState(() => error = 'Ingresa el código de 6 dígitos.');
      return;
    }

    setState(() {
      isBusy = true;
      error = null;
    });

    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code,
      );

      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verificación en dos pasos activada.'),
        ),
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() {
        error = 'El código no es válido o ya venció. Intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  Future<void> _cancelPendingEnroll() async {
    final factorId = _pendingFactorId;
    if (factorId != null) {
      try {
        await Supabase.instance.client.auth.mfa.unenroll(factorId);
      } catch (_) {
        // El factor quedo sin verificar; no es critico si no se pudo borrar.
      }
    }
    _reload();
  }

  Future<void> _disable(Factor factor) async {
    setState(() {
      isBusy = true;
      error = null;
    });

    try {
      await Supabase.instance.client.auth.mfa.unenroll(factor.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verificación en dos pasos desactivada.'),
        ),
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'No se pudo desactivar: $e');
    } finally {
      if (mounted) {
        setState(() => isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seguridad de tu cuenta'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: FutureBuilder<List<Factor>>(
                future: factorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text('No se pudo cargar: ${snapshot.error}');
                  }

                  final factors = snapshot.data ?? [];

                  if (_pendingFactorId != null) {
                    return _buildEnrollStep();
                  }

                  if (factors.isNotEmpty) {
                    return _buildEnabledState(factors.first);
                  }

                  return _buildDisabledState();
                },
              ),
            ),
            const Divider(height: 24),
            // El sello vive aqui y no solo en Configuracion (D-100): esa
            // pantalla es de owner y admin, asi que la recepcionista y los
            // estilistas -- que son quienes mas probable reportan un problema
            // -- no podian ver su version. Este dialogo lo alcanzan todos los
            // roles y en cualquier tamano de pantalla.
            const _VersionFooter(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildDisabledState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'La verificación en dos pasos es opcional. Al activarla, además '
          'de tu contraseña se te pedirá un código de tu app autenticadora '
          '(Google Authenticator, Authy, etc.) cada vez que inicies sesión.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isBusy ? null : _startEnroll,
          icon: const Icon(Icons.add_moderator_outlined),
          label: Text(isBusy ? 'Preparando...' : 'Activar'),
        ),
      ],
    );
  }

  Widget _buildEnabledState(Factor factor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Verificación en dos pasos activada.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: isBusy ? null : () => _disable(factor),
          icon: const Icon(Icons.remove_moderator_outlined),
          label: Text(isBusy ? 'Desactivando...' : 'Desactivar'),
        ),
      ],
    );
  }

  Widget _buildEnrollStep() {
    final qrCode = _pendingQrCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escanea este código con tu app autenticadora:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (qrCode != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.string(qrCode, width: 180, height: 180),
            ),
          ),
        if (_pendingSecret != null) ...[
          const SizedBox(height: 12),
          const Text(
            '¿No puedes escanear? Ingresa este código manualmente:',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          SelectableText(
            _pendingSecret!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Ingresa el código de 6 dígitos que muestra la app:'),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (_) => _confirmEnroll(),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: isBusy ? null : _cancelPendingEnroll,
              child: const Text('Cancelar'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: isBusy ? null : _confirmEnroll,
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verificar y activar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sello de version accesible para cualquier rol (D-100).
///
/// Cuando alguien reporte un problema se le pide este codigo: dice exactamente
/// que version esta ejecutando, sin depender de que recuerde si actualizo.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppVersion?>(
      valueListenable: AppVersionHolder.bootVersion,
      builder: (context, version, _) {
        final texto = (version == null || version.isDevelopment)
            ? 'Versión: en desarrollo'
            : 'Versión: ${version.shortCommit}';

        return Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 15,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$texto · inclúyela si reportas un problema',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
