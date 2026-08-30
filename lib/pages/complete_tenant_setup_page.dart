import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../services/tenant_registration_service.dart';

/// Se muestra cuando hay una sesión autenticada pero el usuario todavía no
/// ha completado la solicitud de registro de su negocio.
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
  final cityController = TextEditingController();

  String selectedBusinessType = 'salon';
  int selectedBranches = 1;
  int selectedTeamSize = 2;
  String selectedReferralSource = 'instagram';

  bool isLoading = false;
  String? errorMessage;

  final List<Map<String, String>> businessTypeOptions = const [
    {'value': 'salon', 'label': 'Peluquería / Salón de Belleza'},
    {'value': 'unas', 'label': 'Spa de Uñas (Nail Spa)'},
    {'value': 'barberia', 'label': 'Barbería'},
    {'value': 'spa', 'label': 'Centro de Estética / Spa'},
    {'value': 'canina', 'label': 'Peluquería / Estética Canina'},
    {'value': 'otro', 'label': 'Otro centro de cuidado personal'},
  ];

  final List<Map<String, dynamic>> teamSizeOptions = [
    {'value': 1, 'label': '1 persona (Trabajo individual)'},
    {'value': 3, 'label': '2 a 5 personas'},
    {'value': 8, 'label': '6 a 15 personas'},
    {'value': 20, 'label': 'Más de 15 personas'},
  ];

  final List<Map<String, String>> referralOptions = const [
    {'value': 'instagram', 'label': 'Instagram'},
    {'value': 'facebook', 'label': 'Facebook / TikTok'},
    {'value': 'recomendacion', 'label': 'Recomendación de un colega'},
    {
      'value': 'visita_comercial',
      'label': 'Visita de un asesor de Salón y Más',
    },
    {'value': 'google', 'label': 'Google / Búsqueda web'},
    {'value': 'otro', 'label': 'Otro medio'},
  ];

  @override
  void dispose() {
    businessNameController.dispose();
    ownerFullNameController.dispose();
    whatsappController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final businessName = businessNameController.text.trim();
    final ownerFullName = ownerFullNameController.text.trim();
    final whatsapp = whatsappController.text.trim();
    final city = cityController.text.trim();

    if (businessName.isEmpty ||
        ownerFullName.isEmpty ||
        whatsapp.isEmpty ||
        city.isEmpty) {
      setState(() {
        errorMessage =
            'Por favor completa nombre del negocio, tu nombre, WhatsApp y ciudad.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Enlace de partner (D-173): ej. "salonymas.com/?ref=CARLOS". Se lee de
      // la URL del navegador directamente -- esta app no cambia de URL entre
      // pantallas internas, así que sigue disponible aquí aunque el clic al
      // enlace haya pasado por el login/registro antes de llegar a este paso.
      final referralCodeUsed = Uri.base.queryParameters['ref']?.trim();

      await tenantRegistrationService.registerTenant(
        businessName: businessName,
        ownerFullName: ownerFullName,
        whatsapp: whatsapp,
        businessType: selectedBusinessType,
        city: city,
        estimatedBranches: selectedBranches,
        estimatedTeamSize: selectedTeamSize,
        referralSource: selectedReferralSource,
        referralCodeUsed:
            (referralCodeUsed != null && referralCodeUsed.isNotEmpty)
            ? referralCodeUsed
            : null,
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
      debugPrint('CompleteTenantSetupPage.submit failed: $error\n$stackTrace');
      setState(() {
        errorMessage =
            'Ocurrió un error inesperado al enviar tu solicitud: $error';
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
      backgroundColor: AppColors.brandSurface,
      appBar: AppBar(
        title: const Text('Solicitud de Registro — Salón y Más'),
        backgroundColor: AppColors.brand,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        color: AppColors.brand,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cuéntanos sobre tu negocio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Revisaremos tu solicitud para configurar tu cuenta personalizada y activar tu prueba gratis de 21 días.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nombre del negocio
                    TextField(
                      controller: businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio *',
                        hintText: 'Ej. Spa de Uñas Glamour',
                        prefixIcon: Icon(Icons.store_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipo de negocio
                    DropdownButtonFormField<String>(
                      initialValue: selectedBusinessType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de negocio *',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: businessTypeOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedBusinessType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nombre del dueño
                    TextField(
                      controller: ownerFullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre completo *',
                        hintText: 'Ej. María Pérez',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp y Ciudad en dos columnas
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: whatsappController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp *',
                              hintText: 'Ej. 3101234567',
                              prefixIcon: Icon(Icons.chat_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: cityController,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad *',
                              hintText: 'Ej. Bogotá / Medellín',
                              prefixIcon: Icon(Icons.location_city_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Número de sedes y tamaño de equipo
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedBranches,
                            decoration: const InputDecoration(
                              labelText: 'Sedes',
                              prefixIcon: Icon(Icons.apartment_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 sede')),
                              DropdownMenuItem(
                                value: 2,
                                child: Text('2 sedes'),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text('3 sedes'),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text('4 o más'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedBranches = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedTeamSize,
                            decoration: const InputDecoration(
                              labelText: 'Equipo',
                              prefixIcon: Icon(Icons.groups_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: teamSizeOptions.map((opt) {
                              return DropdownMenuItem<int>(
                                value: opt['value'] as int,
                                child: Text(
                                  opt['label'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedTeamSize = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cómo nos conociste
                    DropdownButtonFormField<String>(
                      initialValue: selectedReferralSource,
                      decoration: const InputDecoration(
                        labelText: '¿Cómo nos conociste?',
                        prefixIcon: Icon(Icons.campaign_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: referralOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedReferralSource = val);
                        }
                      },
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
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
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          isLoading
                              ? 'Enviando solicitud...'
                              : 'Enviar solicitud de ingreso',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
