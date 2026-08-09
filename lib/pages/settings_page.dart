import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/appointment_policy.dart';
import '../models/business_hour.dart';
import '../models/business_settings.dart';
import '../models/commission_policy.dart';
import '../models/stylist_commission_override.dart';
import '../models/stylist_management_item.dart';
import '../services/appointment_policy_service.dart';
import '../services/business_hours_service.dart';
import '../services/business_settings_service.dart';
import '../services/commission_policy_service.dart';
import '../services/stylists_service.dart';
import '../services/tenant_cover_upload_service.dart';
import '../services/tenant_logo_upload_service.dart';
import '../services/app_version_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/theme_selector_card.dart';
import '../widgets/update_banner.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({
    super.key,
    required this.branchId,
    required this.isOwner,
  });

  final String branchId;
  final bool isOwner;

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final BusinessSettingsService businessSettingsService =
      const BusinessSettingsService();

  late final BusinessHoursService businessHoursService;
  late final AppointmentPolicyService appointmentPolicyService;
  late final CommissionPolicyService commissionPolicyService;
  final StylistsService stylistsService = const StylistsService();

  late Future<BusinessSettings> businessSettingsFuture;
  late Future<List<BusinessHour>> businessHoursFuture;
  late Future<AppointmentPolicy> appointmentPolicyFuture;
  late Future<CommissionPolicy> commissionPolicyFuture;
  late Future<List<StylistManagementItem>> stylistsFuture;

  @override
  void initState() {
    super.initState();
    businessHoursService = BusinessHoursService(branchId: widget.branchId);
    appointmentPolicyService = AppointmentPolicyService(
      branchId: widget.branchId,
    );
    commissionPolicyService = CommissionPolicyService(
      branchId: widget.branchId,
    );
    businessSettingsFuture = businessSettingsService.getBusinessSettings();
    businessHoursFuture = businessHoursService.getBusinessHours();
    appointmentPolicyFuture = appointmentPolicyService.getAppointmentPolicy();
    commissionPolicyFuture = commissionPolicyService.getCommissionPolicy();
    stylistsFuture = stylistsService.getStylistsForManagement(
      widget.branchId,
    );
  }

  void _reloadBusinessSettings() {
    setState(() {
      businessSettingsFuture = businessSettingsService.getBusinessSettings();
    });
  }

  void _reloadHours() {
    setState(() {
      businessHoursFuture = businessHoursService.getBusinessHours();
    });
  }

  void _reloadAppointmentPolicy() {
    setState(() {
      appointmentPolicyFuture = appointmentPolicyService
          .getAppointmentPolicy();
    });
  }

  void _reloadCommissionPolicy() {
    setState(() {
      commissionPolicyFuture = commissionPolicyService.getCommissionPolicy();
    });
  }

  Future<void> _openEditHoursDialog(List<BusinessHour> hours) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditBusinessHoursDialog(
        hours: hours,
        businessHoursService: businessHoursService,
      ),
    );

    if (saved == true) _reloadHours();
  }

  Future<void> _openEditAppointmentPolicyDialog(
    AppointmentPolicy policy,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditAppointmentPolicyDialog(
        policy: policy,
        appointmentPolicyService: appointmentPolicyService,
      ),
    );

    if (saved == true) _reloadAppointmentPolicy();
  }

  Future<void> _openEditCommissionPolicyDialog(CommissionPolicy policy) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditCommissionPolicyDialog(
        policy: policy,
        commissionPolicyService: commissionPolicyService,
      ),
    );

    if (saved == true) _reloadCommissionPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Configuración',
      subtitle: 'Reglas generales del centro de estética.',
      children: [
        const InfoPanel(
          icon: Icons.settings_outlined,
          title: 'Módulo base de Configuración',
          description:
              'Aquí configuraremos datos del negocio, horarios, políticas de agenda, anticipos, comisiones y reglas futuras de WhatsApp e IA.',
        ),
        const SizedBox(height: 16),
        const SectionTitle('Datos del negocio'),
        FutureBuilder<BusinessSettings>(
          future: businessSettingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los datos',
                description:
                    'Revisa la conexión con Supabase o la función get_business_settings.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin datos del negocio',
                description:
                    'Todavía no hay información activa para mostrar en Configuración.',
              );
            }

            return BusinessSettingsCard(
              settings: snapshot.data!,
              isOwner: widget.isOwner,
              businessSettingsService: businessSettingsService,
              onLogoChanged: _reloadBusinessSettings,
            );
          },
        ),
        // Los colores son del negocio, no de la sede (D-093c), y solo los
        // cambia el propietario, igual que el logo. Un admin no ve esta
        // seccion: la identidad visual no es una preferencia de quien esta en
        // el mostrador.
        if (widget.isOwner) ...[
          const SizedBox(height: 16),
          const SectionTitle('Colores de tu negocio'),
          FutureBuilder<BusinessSettings>(
            future: businessSettingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingCard(mensaje: 'Cargando tu tema...');
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const InfoPanel(
                  icon: Icons.palette_outlined,
                  title: 'No se pudo cargar el tema',
                  description:
                      'Vuelve a abrir Configuración. Mientras tanto tu negocio '
                      'sigue viéndose con los colores que ya tenía.',
                );
              }

              return ThemeSelectorCard(
                settings: snapshot.data!,
                businessSettingsService: businessSettingsService,
                onChanged: _reloadBusinessSettings,
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        const SectionTitle('Reserva pública'),
        PublicBookingLinkCard(branchId: widget.branchId),
        const SizedBox(height: 16),
        const SectionTitle('Horarios de atención'),
        FutureBuilder<List<BusinessHour>>(
          future: businessHoursFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los horarios',
                description:
                    'Revisa la conexión con Supabase o el acceso a la sede seleccionada.',
              );
            }

            final hours = snapshot.data ?? [];

            if (hours.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin horarios registrados',
                description:
                    'Todavía no hay horarios activos para mostrar en Configuración.',
              );
            }

            return BusinessHoursCard(
              hours: hours,
              onEdit: () => _openEditHoursDialog(hours),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Políticas de agenda'),
        FutureBuilder<AppointmentPolicy>(
          future: appointmentPolicyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar las políticas',
                description:
                    'Revisa la conexión con Supabase o el acceso a la sede seleccionada.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin políticas registradas',
                description:
                    'Todavía no hay políticas activas para mostrar en Configuración.',
              );
            }

            return AppointmentPolicyCard(
              policy: snapshot.data!,
              onEdit: () => _openEditAppointmentPolicyDialog(snapshot.data!),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Comisiones'),
        FutureBuilder<CommissionPolicy>(
          future: commissionPolicyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar las comisiones',
                description:
                    'Revisa la conexión con Supabase o la función get_commission_policy.',
              );
            }

            if (!snapshot.hasData) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin comisiones registradas',
                description:
                    'Todavía no hay reglas activas de comisión para mostrar en Configuración.',
              );
            }

            return CommissionPolicyCard(
              policy: snapshot.data!,
              onEdit: () => _openEditCommissionPolicyDialog(snapshot.data!),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Excepciones de comisión por estilista'),
        FutureBuilder<List<StylistManagementItem>>(
          future: stylistsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los estilistas',
                description:
                    'Revisa la conexión con Supabase o el acceso a la sede seleccionada.',
              );
            }

            final stylists = (snapshot.data ?? [])
                .where((stylist) => stylist.active)
                .toList();

            if (stylists.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin estilistas activos',
                description:
                    'Crea estilistas en "Estilistas" para poder fijarles una comisión distinta a la del negocio.',
              );
            }

            return StylistCommissionExceptionsCard(
              stylists: stylists,
              commissionPolicyService: commissionPolicyService,
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Versión'),
        const _VersionStamp(),
      ],
    );
  }
}

/// Sello de version (D-099).
///
/// Existe por una razon practica: el 06-ago costo tres rondas averiguar que
/// version estaba ejecutando el propietario. Cuando un negocio reporte algo
/// raro, se le pide este codigo y se sabe al instante si esta viendo la
/// version actual o una de hace dias.
class _VersionStamp extends StatelessWidget {
  const _VersionStamp();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppVersion?>(
      valueListenable: AppVersionHolder.bootVersion,
      builder: (context, version, _) {
        if (version == null || version.isDevelopment) {
          return const _SettingsLine(
            label: 'Versión',
            value: 'En desarrollo (sin publicar)',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsLine(label: 'Versión', value: version.shortCommit),
            if (version.builtAt != null)
              _SettingsLine(label: 'Publicada', value: version.builtAt!),
            const SizedBox(height: 4),
            const Text(
              'Si reportas un problema, incluye este código: dice exactamente qué versión estás viendo.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}

class BusinessSettingsCard extends StatelessWidget {
  final BusinessSettings settings;
  final bool isOwner;
  final BusinessSettingsService businessSettingsService;
  final VoidCallback onLogoChanged;

  const BusinessSettingsCard({
    super.key,
    required this.settings,
    required this.isOwner,
    required this.businessSettingsService,
    required this.onLogoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TenantLogoPreview(logoUrl: settings.logoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    settings.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (isOwner) ...[
              const SizedBox(height: 10),
              _LogoUploadButton(
                tenantId: settings.id,
                logoUrlActual: settings.logoUrl,
                businessSettingsService: businessSettingsService,
                onChanged: onLogoChanged,
              ),
            ],
            const SizedBox(height: 16),
            _TenantCoverPreview(coverPhotoUrl: settings.coverPhotoUrl),
            if (isOwner) ...[
              const SizedBox(height: 10),
              _CoverPhotoUploadButton(
                tenantId: settings.id,
                coverUrlActual: settings.coverPhotoUrl,
                businessSettingsService: businessSettingsService,
                onChanged: onLogoChanged,
              ),
            ],
            const SizedBox(height: 12),
            _SettingsLine(
              label: 'Tipo de negocio',
              value: settings.businessType,
            ),
            _SettingsLine(label: 'Correo', value: settings.contactEmail),
            _SettingsLine(label: 'Teléfono', value: settings.contactPhone),
            _SettingsLine(label: 'WhatsApp', value: settings.whatsapp),
            _SettingsLine(label: 'Instagram', value: settings.instagram),
            _SettingsLine(label: 'Facebook', value: settings.facebook),
          ],
        ),
      ),
    );
  }
}

class _TenantLogoPreview extends StatelessWidget {
  const _TenantLogoPreview({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.storefront_outlined, color: AppColors.brand)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                color: AppColors.brand,
              ),
            ),
    );
  }
}

class _LogoUploadButton extends StatefulWidget {
  const _LogoUploadButton({
    required this.tenantId,
    required this.logoUrlActual,
    required this.businessSettingsService,
    required this.onChanged,
  });

  final String tenantId;
  /// La direccion del logo que se va a reemplazar, para poder borrar ese
  /// archivo despues de subir el nuevo (H-09).
  final String? logoUrlActual;
  final BusinessSettingsService businessSettingsService;
  final VoidCallback onChanged;

  @override
  State<_LogoUploadButton> createState() => _LogoUploadButtonState();
}

class _LogoUploadButtonState extends State<_LogoUploadButton> {
  final _uploadService = const TenantLogoUploadService();
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final XFile? image = await _uploadService.pickImage();
    if (image == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final logoUrl = await _uploadService.uploadTenantLogo(
        tenantId: widget.tenantId,
        image: image,
        previousUrl: widget.logoUrlActual,
      );
      await widget.businessSettingsService.updateTenantLogo(logoUrl);

      if (!mounted) return;
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : 'No se pudo subir el logo: $error';
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickAndUpload,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined, size: 18),
          label: Text(
            _isUploading
                ? 'Subiendo...'
                : (widget.logoUrlActual != null
                      ? 'Cambiar logo'
                      : 'Subir logo'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    );
  }
}

class _TenantCoverPreview extends StatelessWidget {
  const _TenantCoverPreview({required this.coverPhotoUrl});

  final String? coverPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverPhotoUrl;
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.image_outlined, color: AppColors.brand)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                color: AppColors.brand,
              ),
            ),
    );
  }
}

class _CoverPhotoUploadButton extends StatefulWidget {
  const _CoverPhotoUploadButton({
    required this.tenantId,
    required this.coverUrlActual,
    required this.businessSettingsService,
    required this.onChanged,
  });

  final String tenantId;
  /// La direccion de la portada que se va a reemplazar (H-09).
  final String? coverUrlActual;
  final BusinessSettingsService businessSettingsService;
  final VoidCallback onChanged;

  @override
  State<_CoverPhotoUploadButton> createState() =>
      _CoverPhotoUploadButtonState();
}

class _CoverPhotoUploadButtonState extends State<_CoverPhotoUploadButton> {
  final _uploadService = const TenantCoverUploadService();
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final XFile? image = await _uploadService.pickImage();
    if (image == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final coverPhotoUrl = await _uploadService.uploadTenantCoverPhoto(
        tenantId: widget.tenantId,
        image: image,
        previousUrl: widget.coverUrlActual,
      );
      await widget.businessSettingsService.updateTenantCoverPhoto(
        coverPhotoUrl,
      );

      if (!mounted) return;
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : 'No se pudo subir la portada: $error';
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickAndUpload,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined, size: 18),
          label: Text(
            _isUploading
                ? 'Subiendo...'
                : (widget.coverUrlActual != null
                      ? 'Cambiar portada'
                      : 'Subir portada'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    );
  }
}

class PublicBookingLinkCard extends StatelessWidget {
  const PublicBookingLinkCard({super.key, required this.branchId});

  final String branchId;

  String get _link => '${Uri.base.origin}/?reservar=$branchId';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte este enlace por WhatsApp, redes o un código QR '
              'generado a partir de él. Tus clientes reservan sin crear '
              'cuenta ni contraseña; la reserva queda pendiente de tu '
              'confirmación.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar enlace',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => _copyLink(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessHoursCard extends StatelessWidget {
  final List<BusinessHour> hours;
  final VoidCallback onEdit;

  const BusinessHoursCard({super.key, required this.hours, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final hour in hours) _BusinessHourRow(hour: hour),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar horario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentPolicyCard extends StatelessWidget {
  final AppointmentPolicy policy;
  final VoidCallback onEdit;

  const AppointmentPolicyCard({
    super.key,
    required this.policy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsLine(label: 'Anticipo', value: policy.depositText),
            _SettingsLine(label: 'Cancelación', value: policy.cancellationText),
            _SettingsLine(
              label: 'Reagendamiento',
              value: policy.rescheduleText,
            ),
            _SettingsLine(
              label: 'Confirmación',
              value: policy.manualConfirmationText,
            ),
            _SettingsLine(
              label: 'Cliente',
              value: policy.customerRescheduleText,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar política'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommissionPolicyCard extends StatelessWidget {
  final CommissionPolicy policy;
  final VoidCallback onEdit;

  const CommissionPolicyCard({
    super.key,
    required this.policy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsLine(label: 'Tipo', value: policy.commissionTypeText),
            _SettingsLine(label: 'Comisión', value: policy.commissionValueText),
            _SettingsLine(label: 'Descuentos', value: policy.discountText),
            _SettingsLine(label: 'Notas', value: policy.notes),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar comisión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StylistCommissionExceptionsCard extends StatelessWidget {
  const StylistCommissionExceptionsCard({
    super.key,
    required this.stylists,
    required this.commissionPolicyService,
  });

  final List<StylistManagementItem> stylists;
  final CommissionPolicyService commissionPolicyService;

  Future<void> _openDialog(BuildContext context, StylistManagementItem stylist) {
    return showDialog(
      context: context,
      builder: (_) => _StylistCommissionOverridesDialog(
        stylist: stylist,
        commissionPolicyService: commissionPolicyService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Fija una comisión distinta a la general del negocio para un '
              'estilista en un servicio específico. Sin excepciones, se usa '
              'la comisión general de arriba.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final stylist in stylists)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stylist.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openDialog(context, stylist),
                      icon: const Icon(Icons.percent_outlined, size: 18),
                      label: const Text('Editar excepciones'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StylistCommissionOverridesDialog extends StatefulWidget {
  const _StylistCommissionOverridesDialog({
    required this.stylist,
    required this.commissionPolicyService,
  });

  final StylistManagementItem stylist;
  final CommissionPolicyService commissionPolicyService;

  @override
  State<_StylistCommissionOverridesDialog> createState() =>
      _StylistCommissionOverridesDialogState();
}

class _StylistCommissionOverridesDialogState
    extends State<_StylistCommissionOverridesDialog> {
  late Future<List<StylistCommissionOverride>> overridesFuture;

  @override
  void initState() {
    super.initState();
    overridesFuture = widget.commissionPolicyService
        .getStylistCommissionOverrides(widget.stylist.id);
  }

  void _reload() {
    setState(() {
      overridesFuture = widget.commissionPolicyService
          .getStylistCommissionOverrides(widget.stylist.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comisiones de ${widget.stylist.name}'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<StylistCommissionOverride>>(
          future: overridesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'No se pudieron cargar los servicios: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final overrides = snapshot.data ?? [];

            if (overrides.isEmpty) {
              return const Text(
                'Este estilista no tiene servicios asignados en esta sede '
                'todavía.',
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final override in overrides)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ServiceCommissionRow(
                        stylistId: widget.stylist.id,
                        commissionOverride: override,
                        commissionPolicyService: widget.commissionPolicyService,
                        onChanged: _reload,
                      ),
                    ),
                ],
              ),
            );
          },
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
}

class _ServiceCommissionRow extends StatefulWidget {
  const _ServiceCommissionRow({
    required this.stylistId,
    required this.commissionOverride,
    required this.commissionPolicyService,
    required this.onChanged,
  });

  final String stylistId;
  final StylistCommissionOverride commissionOverride;
  final CommissionPolicyService commissionPolicyService;
  final VoidCallback onChanged;

  @override
  State<_ServiceCommissionRow> createState() => _ServiceCommissionRowState();
}

class _ServiceCommissionRowState extends State<_ServiceCommissionRow> {
  late bool hasException = widget.commissionOverride.hasOverride;
  late String commissionType =
      widget.commissionOverride.commissionType ?? 'percentage';
  late final percentageController = TextEditingController(
    text: (widget.commissionOverride.commissionPercentage ?? 0).toString(),
  );
  late final fixedController = TextEditingController(
    text: (widget.commissionOverride.fixedCommissionAmount ?? 0).toString(),
  );
  bool isSaving = false;
  String? error;

  @override
  void dispose() {
    percentageController.dispose();
    fixedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      isSaving = true;
      error = null;
    });

    try {
      if (hasException) {
        final percentage = num.tryParse(percentageController.text.trim());
        final fixed = num.tryParse(fixedController.text.trim());

        if (percentage == null || percentage < 0 || percentage > 100) {
          setState(() {
            error = 'El porcentaje debe ser entre 0 y 100.';
            isSaving = false;
          });
          return;
        }
        if (fixed == null || fixed < 0) {
          setState(() {
            error = 'El valor fijo no puede ser negativo.';
            isSaving = false;
          });
          return;
        }

        await widget.commissionPolicyService.setStylistServiceCommission(
          stylistId: widget.stylistId,
          serviceId: widget.commissionOverride.serviceId,
          commissionType: commissionType,
          commissionPercentage: percentage,
          fixedCommissionAmount: fixed,
        );
      } else if (widget.commissionOverride.hasOverride) {
        await widget.commissionPolicyService
            .removeStylistServiceCommissionOverride(
          stylistId: widget.stylistId,
          serviceId: widget.commissionOverride.serviceId,
        );
      }

      widget.onChanged();
    } on PostgrestException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.commissionOverride.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: hasException,
                onChanged: (value) => setState(() => hasException = value),
              ),
            ],
          ),
          if (!hasException)
            const Text(
              'Usa la comisión general del negocio.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: commissionType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'percentage',
                        child: Text('Porcentaje'),
                      ),
                      DropdownMenuItem(value: 'fixed', child: Text('Valor fijo')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => commissionType = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: commissionType == 'percentage'
                        ? percentageController
                        : fixedController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: commissionType == 'percentage'
                          ? 'Porcentaje (%)'
                          : 'Valor fijo (COP)',
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBusinessHoursDialog extends StatefulWidget {
  const _EditBusinessHoursDialog({
    required this.hours,
    required this.businessHoursService,
  });

  final List<BusinessHour> hours;
  final BusinessHoursService businessHoursService;

  @override
  State<_EditBusinessHoursDialog> createState() =>
      _EditBusinessHoursDialogState();
}

class _EditBusinessHoursDialogState extends State<_EditBusinessHoursDialog> {
  late final List<_EditableDay> days = widget.hours
      .map((hour) => _EditableDay.fromBusinessHour(hour))
      .toList()
    ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

  bool isSaving = false;
  String? errorMessage;

  Future<void> _pickTime(_EditableDay day, {required bool isOpening}) async {
    final initial = isOpening ? day.opensAt : day.closesAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked == null) return;

    setState(() {
      if (isOpening) {
        day.opensAt = picked;
      } else {
        day.closesAt = picked;
      }
    });
  }

  Future<void> save() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final updated = days
          .map(
            (day) => BusinessHour(
              id: day.id,
              dayOfWeek: day.dayOfWeek,
              opensAt: day.isOpen ? _formatTime(day.opensAt) : null,
              closesAt: day.isOpen ? _formatTime(day.closesAt) : null,
              isOpen: day.isOpen,
            ),
          )
          .toList();

      await widget.businessHoursService.updateBusinessHours(updated);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar horario de atención'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in days) _DayRow(day: day, onPickTime: _pickTime),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onPickTime});

  final _EditableDay day;
  final void Function(_EditableDay day, {required bool isOpening}) onPickTime;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(day.dayName)),
              Switch(
                value: day.isOpen,
                onChanged: (value) => setLocalState(() => day.isOpen = value),
              ),
              if (day.isOpen) ...[
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      onPickTime(day, isOpening: true);
                    },
                    child: Text(day.opensAt?.format(context) ?? 'Apertura'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      onPickTime(day, isOpening: false);
                    },
                    child: Text(day.closesAt?.format(context) ?? 'Cierre'),
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'Cerrado',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditableDay {
  _EditableDay({
    required this.id,
    required this.dayOfWeek,
    required this.dayName,
    required this.isOpen,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final int dayOfWeek;
  final String dayName;
  bool isOpen;
  TimeOfDay? opensAt;
  TimeOfDay? closesAt;

  factory _EditableDay.fromBusinessHour(BusinessHour hour) {
    return _EditableDay(
      id: hour.id,
      dayOfWeek: hour.dayOfWeek,
      dayName: hour.dayName,
      isOpen: hour.isOpen,
      opensAt: _parseTime(hour.opensAt),
      closesAt: _parseTime(hour.closesAt),
    );
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.length < 5) return null;
    final hour = int.tryParse(value.substring(0, 2));
    final minute = int.tryParse(value.substring(3, 5));
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _EditAppointmentPolicyDialog extends StatefulWidget {
  const _EditAppointmentPolicyDialog({
    required this.policy,
    required this.appointmentPolicyService,
  });

  final AppointmentPolicy policy;
  final AppointmentPolicyService appointmentPolicyService;

  @override
  State<_EditAppointmentPolicyDialog> createState() =>
      _EditAppointmentPolicyDialogState();
}

class _EditAppointmentPolicyDialogState
    extends State<_EditAppointmentPolicyDialog> {
  late bool requiresDeposit = widget.policy.requiresDeposit;
  late final depositController = TextEditingController(
    text: widget.policy.depositPercentage.toStringAsFixed(0),
  );
  late final cancellationController = TextEditingController(
    text: widget.policy.cancellationHours.toString(),
  );
  late final rescheduleController = TextEditingController(
    text: widget.policy.rescheduleHours.toString(),
  );
  late bool manualConfirmationRequired =
      widget.policy.manualConfirmationRequired;
  late bool customerRescheduleAllowed =
      widget.policy.customerRescheduleAllowed;
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    depositController.dispose();
    cancellationController.dispose();
    rescheduleController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final deposit = num.tryParse(depositController.text.trim());
    final cancellation = int.tryParse(cancellationController.text.trim());
    final reschedule = int.tryParse(rescheduleController.text.trim());

    if (deposit == null || deposit < 0 || deposit > 100) {
      setState(() => errorMessage = 'El anticipo debe ser entre 0 y 100.');
      return;
    }
    if (cancellation == null || cancellation < 0) {
      setState(() => errorMessage = 'Las horas de cancelación no son válidas.');
      return;
    }
    if (reschedule == null || reschedule < 0) {
      setState(
        () => errorMessage = 'Las horas de reagendamiento no son válidas.',
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.appointmentPolicyService.updateAppointmentPolicy(
        requiresDeposit: requiresDeposit,
        depositPercentage: deposit,
        cancellationHours: cancellation,
        rescheduleHours: reschedule,
        manualConfirmationRequired: manualConfirmationRequired,
        customerRescheduleAllowed: customerRescheduleAllowed,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar política de citas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere anticipo'),
              value: requiresDeposit,
              onChanged: (value) => setState(() => requiresDeposit = value),
            ),
            if (requiresDeposit)
              TextField(
                controller: depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Anticipo (%)'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: cancellationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Horas mínimas para cancelar',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rescheduleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Horas mínimas para reagendar',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere confirmación manual'),
              value: manualConfirmationRequired,
              onChanged: (value) =>
                  setState(() => manualConfirmationRequired = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('El cliente puede reagendar'),
              value: customerRescheduleAllowed,
              onChanged: (value) =>
                  setState(() => customerRescheduleAllowed = value),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _EditCommissionPolicyDialog extends StatefulWidget {
  const _EditCommissionPolicyDialog({
    required this.policy,
    required this.commissionPolicyService,
  });

  final CommissionPolicy policy;
  final CommissionPolicyService commissionPolicyService;

  @override
  State<_EditCommissionPolicyDialog> createState() =>
      _EditCommissionPolicyDialogState();
}

class _EditCommissionPolicyDialogState
    extends State<_EditCommissionPolicyDialog> {
  late String commissionType = widget.policy.commissionType;
  late final percentageController = TextEditingController(
    text: widget.policy.commissionPercentage.toStringAsFixed(0),
  );
  late final fixedController = TextEditingController(
    text: widget.policy.fixedCommissionAmount.toStringAsFixed(0),
  );
  late bool appliesAfterDiscount = widget.policy.appliesAfterDiscount;
  late final notesController = TextEditingController(
    text: widget.policy.notes == 'Sin notas' ? '' : widget.policy.notes,
  );
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    percentageController.dispose();
    fixedController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final percentage = num.tryParse(percentageController.text.trim());
    final fixed = num.tryParse(fixedController.text.trim());

    if (percentage == null || percentage < 0 || percentage > 100) {
      setState(() => errorMessage = 'El porcentaje debe ser entre 0 y 100.');
      return;
    }
    if (fixed == null || fixed < 0) {
      setState(() => errorMessage = 'El valor fijo no es válido.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.commissionPolicyService.updateCommissionPolicy(
        commissionType: commissionType,
        commissionPercentage: percentage,
        fixedCommissionAmount: fixed,
        appliesAfterDiscount: appliesAfterDiscount,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar política de comisión'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: commissionType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Porcentaje')),
                DropdownMenuItem(value: 'fixed', child: Text('Valor fijo')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => commissionType = value);
              },
            ),
            const SizedBox(height: 12),
            if (commissionType == 'percentage')
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje de comisión (%)',
                ),
              )
            else
              TextField(
                controller: fixedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor fijo por servicio (COP)',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Calcular después de descuentos'),
              value: appliesAfterDiscount,
              onChanged: (value) =>
                  setState(() => appliesAfterDiscount = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _BusinessHourRow extends StatelessWidget {
  final BusinessHour hour;

  const _BusinessHourRow({required this.hour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              hour.dayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(hour.scheduleText)),
        ],
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
