import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tenant_registration_service.dart';

/// Se muestra cuando hay una sesión autenticada pero el usuario todavía no
/// tiene negocio ni rol de plataforma (por ejemplo: confirmó su correo
/// después de registrarse y `register_tenant` nunca se llamó).
class CompleteTenantSetupPage extends StatefulWidget {
  const CompleteTenantSetupPage({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<CompleteTenantSetupPage> createState() =>
      _CompleteTenantSetupPageState();
}

class _CompleteTenantSetupPageState extends State<CompleteTenantSetupPage> {
  final tenantRegistrationService = const TenantRegistrationService();

  final businessNameController = TextEditingController();
  final ownerFullNameController = TextEditingController();
  final whatsappController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    businessNameController.dispose();
    ownerFullNameController.dispose();
    whatsappController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final businessName = businessNameController.text.trim();
    final ownerFullName = ownerFullNameController.text.trim();
    final whatsapp = whatsappController.text.trim();

    if (businessName.isEmpty || ownerFullName.isEmpty || whatsapp.isEmpty) {
      setState(() {
        errorMessage = 'Completa nombre del negocio, tu nombre y WhatsApp.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await tenantRegistrationService.registerTenant(
        businessName: businessName,
        ownerFullName: ownerFullName,
        whatsapp: whatsapp,
      );

      if (!mounted) {
        return;
      }

      widget.onCompleted();
    } on PostgrestException catch (error) {
      setState(() {
        errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      // Temporal mientras se valida el flujo de registro de punta a punta:
      // mostrar el error real ayuda a diagnosticar en vez de adivinar.
      debugPrint('CompleteTenantSetupPage.submit failed: $error\n$stackTrace');
      setState(() {
        errorMessage = 'Ocurrió un error inesperado al crear tu negocio: '
            '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EF),
      appBar: AppBar(
        title: const Text('Completa tu negocio'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                    const Text(
                      'Ya casi. Cuéntanos de tu negocio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Con esto activamos tu prueba gratis de 21 días.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF795548)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ownerFullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp de contacto',
                        prefixIcon: Icon(Icons.chat_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => submit(),
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
                        onPressed: isLoading ? null : submit,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isLoading ? 'Creando...' : 'Empezar prueba gratis',
                        ),
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
