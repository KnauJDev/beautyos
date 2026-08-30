import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/platform_partner.dart';
import '../services/public_partner_service.dart';
import '../theme/app_theme.dart';
import 'agenda_page.dart' show buildWhatsAppUri;

/// Postulación pública de Partners (Paso 7.3 / D-173): "salonymas.com/partners"
/// o "?partners=1". Cualquier persona puede postularse sin sesión.
class PublicPartnerPage extends StatefulWidget {
  const PublicPartnerPage({super.key});

  @override
  State<PublicPartnerPage> createState() => _PublicPartnerPageState();
}

class _PublicPartnerPageState extends State<PublicPartnerPage> {
  final _service = const PublicPartnerService();
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _payoutAccountController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String _payoutChannel = 'bre_b';
  bool _isSubmitting = false;
  String? _errorMessage;
  PublicPartnerRegistrationResult? _result;

  static const _channelOptions = [
    {'value': 'bre_b', 'label': 'Llave Bre-B'},
    {'value': 'daviplata', 'label': 'Daviplata'},
    {'value': 'nequi', 'label': 'Nequi'},
    {'value': 'bancolombia', 'label': 'Bancolombia'},
    {'value': 'otro', 'label': 'Otro'},
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _documentIdController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _payoutAccountController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  String get _referralLink =>
      '${Uri.base.origin}/?ref=${_result?.referralCode ?? ''}';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.registerPartner(
        fullName: _fullNameController.text.trim(),
        documentId: _documentIdController.text.trim().isEmpty
            ? null
            : _documentIdController.text.trim(),
        referralCode: _referralCodeController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        payoutChannel: _payoutChannel,
        payoutAccount: _payoutAccountController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst(
          RegExp(r'^[A-Za-z]+Exception:\s*'),
          '',
        );
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _referralLink));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  Future<void> _shareByWhatsApp() async {
    final message =
        'Ya soy Partner de Salón y Más 🎉 Este es mi enlace para recomendar '
        'el software de gestión #1 para salones de belleza en Colombia: '
        '$_referralLink';
    final uri = buildWhatsAppUri(
      _whatsappController.text.trim(),
      text: message,
    );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _result != null ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandDark],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sé Partner de Salón y Más',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Gana comisiones recomendando el software #1 de belleza en Colombia. Regístrate en 30 segundos y comparte tu enlace.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.dangerTint,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tu nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _documentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Cédula (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      hintText: 'Ej. 3001234567',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tu WhatsApp es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _payoutChannel,
                    decoration: const InputDecoration(
                      labelText: 'Canal de pago',
                      border: OutlineInputBorder(),
                    ),
                    items: _channelOptions
                        .map(
                          (opt) => DropdownMenuItem(
                            value: opt['value'],
                            child: Text(opt['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _payoutChannel = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _payoutAccountController,
                    decoration: InputDecoration(
                      labelText:
                          'Llave o número de cuenta (${partnerPayoutChannelLabel(_payoutChannel)})',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tu llave o cuenta de pago es obligatoria'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _referralCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código deseado',
                      hintText: 'Ej. CARLOS',
                      helperText:
                          'Sin espacios. Letras, números, guion o guion bajo.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Elige un código para tu enlace'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Quiero ser Partner'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 40,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '¡Ya eres Partner de Salón y Más!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Comparte tu enlace y gana comisión cada vez que un salón se registre con tu código y pague su suscripción.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _referralLink,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: _copyLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _shareByWhatsApp,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Compartir por WhatsApp'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}
