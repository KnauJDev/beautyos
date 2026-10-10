import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/enlace_de_reserva.dart';
import '../models/appointment_policy.dart';
import '../models/cifra_escrita.dart';
import '../models/branch_info.dart';
import '../models/business_hour.dart';
import '../models/business_settings.dart';
import '../models/commission_policy.dart';
import '../models/sale_numbering.dart';
import '../models/stylist_commission_override.dart';
import '../models/stylist_management_item.dart';
import '../models/tenant_subscription_status.dart';
import '../models/tipo_de_negocio.dart';
import '../services/appointment_policy_service.dart';
import '../services/branch_sale_numbering_service.dart';
import '../services/branches_service.dart';
import '../services/business_hours_service.dart';
import '../services/business_settings_service.dart';
import '../services/commission_policy_service.dart';
import '../services/stylists_service.dart';
import '../services/tenant_cover_upload_service.dart';
import '../services/tenant_logo_upload_service.dart';
import '../services/tenant_subscription_service.dart';
import '../widgets/dialogo_datos_de_sede.dart';
import '../widgets/sedes_suscripcion_card.dart';
import '../services/app_version_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/codigo_qr_del_enlace.dart' show mostrarCodigoQr;
import '../widgets/create_branch_dialog.dart';
import '../widgets/theme_selector_card.dart';
import '../widgets/update_banner.dart';
import '../services/invitar_a_volver_service.dart';
import '../models/mensaje_para_la_clienta.dart';
import '../models/redes_sociales.dart' show avisoDeRed;

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({
    super.key,
    required this.branchId,
    required this.isOwner,
    required this.onSedeCreada,
    this.citasNacenConfirmadas = false,
    this.esSedePrincipal = false,
    this.sinCaja = false,
    this.sinComisiones = false,
  });

  final String branchId;
  final bool isOwner;

  /// Paso 5 (D-317): la plataforma le apagó la caja a este negocio. No cobra
  /// en la app, así que no numera ventas ni genera comisiones: esas
  /// secciones no se muestran (no se borra nada; vuelven al encender la caja).
  final bool sinCaja;

  /// La plataforma le apagó las comisiones (D-310). Mismo criterio.
  final bool sinComisiones;

  /// D-312: el negocio tiene la caja apagada, y la reserva en línea le llega
  /// confirmada. La tarjeta del enlace no debe decir "pendiente".
  final bool citasNacenConfirmadas;

  /// D-313: en la sede principal, el enlace de reserva es la dirección con
  /// el nombre del salón.
  final bool esSedePrincipal;

  /// Qué hacer cuando el propietario acaba de crear una sede (D-238).
  ///
  /// Obligatorio a propósito: la lista de sedes NO vive en esta página, vive
  /// en el contexto que arma `main.dart`. Crear una sede sin avisarle deja al
  /// propietario delante de un selector que todavía no la conoce -- y con una
  /// sola sede ese selector ni siquiera es un menú, es una etiqueta muerta.
  final VoidCallback onSedeCreada;

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final BusinessSettingsService businessSettingsService =
      const BusinessSettingsService();

  late final BusinessHoursService businessHoursService;
  late final AppointmentPolicyService appointmentPolicyService;
  late final CommissionPolicyService commissionPolicyService;
  late final BranchSaleNumberingService branchSaleNumberingService;
  final StylistsService stylistsService = const StylistsService();

  late Future<BusinessSettings> businessSettingsFuture;
  late Future<List<BusinessHour>> businessHoursFuture;
  late Future<AppointmentPolicy> appointmentPolicyFuture;
  late Future<CommissionPolicy> commissionPolicyFuture;
  late Future<List<StylistManagementItem>> stylistsFuture;
  late Future<BranchSaleNumbering> saleNumberingFuture;

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
    branchSaleNumberingService = BranchSaleNumberingService(
      branchId: widget.branchId,
    );
    businessSettingsFuture = businessSettingsService.getBusinessSettings();
    businessHoursFuture = businessHoursService.getBusinessHours();
    appointmentPolicyFuture = appointmentPolicyService.getAppointmentPolicy();
    commissionPolicyFuture = commissionPolicyService.getCommissionPolicy();
    stylistsFuture = stylistsService.getStylistsForManagement(
      widget.branchId,
    );
    saleNumberingFuture = branchSaleNumberingService.getBranchSaleNumbering();
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

  void _reloadSaleNumbering() {
    setState(() {
      saleNumberingFuture =
          branchSaleNumberingService.getBranchSaleNumbering();
    });
  }

  Future<void> _openEditSaleNumberingDialog(
    BranchSaleNumbering numbering,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditSaleNumberingDialog(
        numbering: numbering,
        branchSaleNumberingService: branchSaleNumberingService,
      ),
    );

    if (saved == true) _reloadSaleNumbering();
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
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
        // Los datos de la sede en la que estas, no los del negocio (D-242).
        // Fuera del `isOwner`: un admin lleva una sede y tiene que poder
        // corregir su telefono o su direccion. Quien manda de verdad es la
        // RPC, que comprueba el permiso **por sede**.
        const SizedBox(height: 16),
        const SectionTitle('Datos de esta sede'),
        _DatosDeEstaSedeCard(branchId: widget.branchId),
        if (widget.isOwner) ...[
          const SizedBox(height: 16),
          const SectionTitle('Sedes'),
          _SedesCard(onSedeCreada: widget.onSedeCreada),
        ],
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
        // D-318 (07-oct): una sola tarjeta donde antes había dos ("Enlace
        // web de tu negocio" y "Reserva pública"), y sin "Modificar enlace".
        const SectionTitle('Tu enlace'),
        FutureBuilder<BusinessSettings>(
          future: businessSettingsFuture,
          builder: (context, snapshot) =>
              snapshot.connectionState == ConnectionState.waiting
              ? const LoadingCard(mensaje: 'Cargando tu enlace...')
              // Si falla, la tarjeta da el enlace directo de la sede.
              : TuEnlaceCard(
                  branchId: widget.branchId,
                  slugDelSalon: snapshot.data?.slug,
                  nombreDelSalon: snapshot.data?.name,
                  citasNacenConfirmadas: widget.citasNacenConfirmadas,
                  esSedePrincipal: widget.esSedePrincipal,
                ),
        ),
        const SizedBox(height: 16),
        // D-314 (4B): el tiempo de volver por defecto del salón.
        const SectionTitle('Invitar a volver'),
        TiempoDeVolverDelSalonCard(branchId: widget.branchId),
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
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
        // Paso 5 (D-317): sin caja o sin comisiones no hay comisiones que
        // configurar.
        if (!widget.sinCaja && !widget.sinComisiones) ...[
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
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
                    'Revisa tu conexión a internet o intenta nuevamente más tarde.',
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
        ],
        if (widget.isOwner) ...[
          // Paso 5 (D-317): sin caja no hay ventas que numerar.
          if (!widget.sinCaja) ...[
          const SizedBox(height: 24),
          const SectionTitle('Numeración de ventas y Resolución DIAN'),
          FutureBuilder<BranchSaleNumbering>(
            future: saleNumberingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingCard(mensaje: 'Cargando numeración...');
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const InfoPanel(
                  icon: Icons.receipt_long_outlined,
                  title: 'Numeración no disponible',
                  description:
                      'No se pudo consultar el consecutivo de ventas de esta sede.',
                );
              }

              return SaleNumberingCard(
                numbering: snapshot.data!,
                isOwner: widget.isOwner,
                onEdit: () => _openEditSaleNumberingDialog(snapshot.data!),
              );
            },
          ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Fotos de trabajos y Portafolio'),
          const _PhotoPolicyCard(),
          const SizedBox(height: 24),
          const SectionTitle('Suscripción y Facturación'),
          // D-328: cerrar o reabrir una sede cambia el selector de sedes.
          _SubscriptionSettingsCard(onSedesCambiaron: widget.onSedeCreada),
        ],
        const SizedBox(height: 24),
        const SectionTitle('Soporte'),
        const _SupportCard(),
        const SizedBox(height: 24),
        const SectionTitle('Versión'),
        const _VersionStamp(),
      ],
    );
  }
}

/// Tarjeta de gestión de suscripción y pagos con ePayco (D-141).
class _SubscriptionSettingsCard extends StatefulWidget {
  const _SubscriptionSettingsCard({this.onSedesCambiaron});

  /// D-328: lo mismo que `onSedeCreada`, para cerrar o reabrir una sede.
  final VoidCallback? onSedesCambiaron;

  @override
  State<_SubscriptionSettingsCard> createState() =>
      _SubscriptionSettingsCardState();
}

class _SubscriptionSettingsCardState extends State<_SubscriptionSettingsCard> {
  final _service = const TenantSubscriptionService();
  // El checkout salió de aquí con AG: esta tarjeta ya no cobra nada. Quien
  // cobra es `SedesSuscripcionCard`, que tiene el suyo.
  late Future<TenantSubscriptionStatus?> _subscriptionFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _subscriptionFuture = _service.getMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantSubscriptionStatus?>(
      future: _subscriptionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final sub = snapshot.data;
        if (sub == null) {
          return const InfoPanel(
            icon: Icons.info_outline,
            title: 'Sin información de suscripción',
            description: 'No se pudo cargar el estado de tu suscripción.',
          );
        }

        // Hallazgo BD: el respaldo era 'Profesional', jubilado por D-188.
        final planName = sub.planName ?? 'Todo Incluido';
        final isFounder = sub.isFounder;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: sub.isGrace ? AppColors.warning : AppColors.border,
              width: sub.isGrace ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color: AppColors.brand,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Plan $planName',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                // Verde solo si además está dentro de su
                                // período (hallazgo BI).
                                decoration: BoxDecoration(
                                  color: sub.isActiveAndCurrent
                                      ? AppColors.successTint
                                      : sub.isGrace
                                          ? AppColors.warningTint
                                          : sub.isTrialing
                                              ? AppColors.brandSurface
                                              : AppColors.dangerTint,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub.statusLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: sub.isActiveAndCurrent
                                        ? AppColors.success
                                        : sub.isGrace
                                            ? AppColors.warning
                                            : sub.isTrialing
                                                ? AppColors.brand
                                                : AppColors.danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Hallazgo AG: aquí había un precio del negocio que
                          // competía con el de cada sede, diez centímetros más
                          // abajo y con otro botón. Los dos eran correctos y
                          // ninguno decía cuál cobraba. **Lo que se paga es
                          // cada sede**, así que el precio vive una sola vez,
                          // junto al botón que lo cobra.
                          const Text(
                            'Lo que pagas es cada sede, abajo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isFounder) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningTint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          // D-221: **el pionero es una etiqueta, no un 50%.**
                          // Aquí seguía prometiéndose por escrito un descuento
                          // que el servidor dejó de aplicar el 07-sep, y para
                          // el que existe el control 207. Un número que no se
                          // cumple es peor que ninguno, y este se le prometía
                          // al cliente, no a nosotros. Encontrado con AG.
                          child: Text(
                            '★ Salón Pionero: tienes una tarifa acordada para tus sedes.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (sub.isGrace) ...[
                  Text(
                    '⚠️ Periodo de gracia: te quedan ${sub.graceDaysRemaining ?? 5} días para pagar antes de que el servicio sea suspendido.',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (sub.isTrialing) ...[
                  Text(
                    'Prueba gratis activa: ${sub.trialDaysRemaining ?? 0} días restantes.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (sub.isPeriodExpired) ...[
                  // Hallazgo BI: hasta el 23-sep aquí decía "Próxima fecha de
                  // renovación" con una fecha que ya había pasado.
                  Text(
                    'Tu período venció el ${sub.currentPeriodEnd!.day}/${sub.currentPeriodEnd!.month}/${sub.currentPeriodEnd!.year}. '
                    'Mientras no lo renueves no se pueden crear citas nuevas. '
                    'Se renueva pagando la sede Principal, aquí abajo.',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (sub.isActive && sub.currentPeriodEnd != null) ...[
                  Text(
                    'Próxima fecha de renovación: ${sub.currentPeriodEnd!.day}/${sub.currentPeriodEnd!.month}/${sub.currentPeriodEnd!.year}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Hallazgo AG: aquí había un botón **"Pagar y Activar Plan con
                // ePayco"** que cobraba el negocio entero, justo encima de los
                // botones que cobran cada sede. Dos botones que cobraban
                // distinto en la misma pantalla.
                //
                // **No cubría ningún caso que el de abajo no cubra:**
                // `get_branch_subscriptions` devuelve TODAS las sedes,
                // incluida la principal. Lo único que hacía era ofrecer pagar
                // por un camino que **no activa ninguna sede** — se pagaba y
                // no pasaba nada.
                //
                // La puerta de ese cobro quedó cerrada en el servidor el
                // 22-sep; quitar el botón es la otra mitad.

                // Las sedes con su estado de pago (D-193). Va aquí dentro y no
                // como tarjeta aparte para reutilizar la suscripción que esta
                // pantalla ya cargó, en vez de pedirla dos veces -- y porque es
                // donde el dueño ya está mirando el dinero.
                const SizedBox(height: 4),
                SedesSuscripcionCard(
                  subscription: sub,
                  // Esta sección solo la ve el dueño (`isOwner`), y cerrar una
                  // sede es del dueño (D-328).
                  puedeCerrar: true,
                  onSedesCambiaron: widget.onSedesCambiaron,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta de soporte: permite al dueño del negocio contactar al equipo
/// de Salón y Más por WhatsApp o correo electrónico desde Configuración.
class _SupportCard extends StatelessWidget {
  const _SupportCard();

  static const _whatsappNumber = '573159780158';
  static const _supportEmail = 'hola@salonymas.com';

  Future<void> _openWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/$_whatsappNumber?text='
      '${Uri.encodeComponent('Hola equipo de Salón y Más 👋\nNecesito ayuda con mi negocio. ¡Gracias!')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEmail() async {
    final url = Uri.parse('mailto:$_supportEmail?subject=Solicitud de soporte');
    await launchUrl(url);
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
              '¿Necesitas ayuda o tienes alguna duda?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Nuestro equipo está listo para apoyarte.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.whatsapp,
                      side: const BorderSide(color: AppColors.whatsapp),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEmail,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Correo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'WhatsApp: +57 315 978 0158  ·  $_supportEmail',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
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
            _ContactInfoEditor(
              settings: settings,
              businessSettingsService: businessSettingsService,
              onChanged: onLogoChanged,
            ),
            const SizedBox(height: 8),
            _SettingsLine(label: 'Correo', value: settings.contactEmail),
          ],
        ),
      ),
    );
  }
}

/// Autoservicio: owner o admin del propio negocio mantienen actualizados el
/// nombre del titular, tipo de negocio, teléfono y WhatsApp (D-161).
class _ContactInfoEditor extends StatefulWidget {
  const _ContactInfoEditor({
    required this.settings,
    required this.businessSettingsService,
    required this.onChanged,
  });

  final BusinessSettings settings;
  final BusinessSettingsService businessSettingsService;
  final VoidCallback onChanged;

  @override
  State<_ContactInfoEditor> createState() => _ContactInfoEditorState();
}

class _ContactInfoEditorState extends State<_ContactInfoEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _tiktokController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.settings.contactName ?? '');
    _businessTypeController = TextEditingController(
      text: etiquetaDelTipoDeNegocio(_tipoOriginal),
    );
    _phoneController = TextEditingController(
      text: _editableOrEmpty(widget.settings.contactPhone, 'Sin teléfono'),
    );
    _whatsappController = TextEditingController(
      text: _editableOrEmpty(widget.settings.whatsapp, 'Sin WhatsApp'),
    );
    _instagramController = TextEditingController(
      text: _editableOrEmpty(widget.settings.instagram, 'Sin Instagram'),
    );
    _facebookController = TextEditingController(
      text: _editableOrEmpty(widget.settings.facebook, 'Sin Facebook'),
    );
    _tiktokController = TextEditingController(text: widget.settings.tiktok ?? '');
  }

  /// [BusinessSettings] rellena estos campos con un texto de reemplazo
  /// ("Sin teléfono", etc.) para mostrarlos en solo lectura en el resto de
  /// la pantalla. Aquí, donde el campo es editable, ese texto de reemplazo
  /// no debe aparecer precargado como si fuera un valor real.
  String _editableOrEmpty(String value, String placeholder) =>
      value == placeholder ? '' : value;

  /// El tipo de negocio tal como está guardado (a menudo el código `salon`).
  /// El campo enseña su texto traducido; si no lo tocan, se guarda esto.
  String get _tipoOriginal =>
      _editableOrEmpty(widget.settings.businessType, 'Sin tipo de negocio');

  @override
  void dispose() {
    _nameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  /// D-321: el aviso de cada red, si lo escrito no lleva a un perfil.
  String? _avisoInstagram;
  String? _avisoFacebook;
  String? _avisoTiktok;

  Future<void> _save() async {
    // Un nombre con espacios ("Inspirant salon") no abre ningún perfil: se
    // avisa en el campo y no se guarda (08-oct, lo que le pasó a David).
    setState(() {
      _avisoInstagram = avisoDeRed(_instagramController.text);
      _avisoFacebook = avisoDeRed(_facebookController.text);
      _avisoTiktok = avisoDeRed(_tiktokController.text);
    });
    if (_avisoInstagram != null || _avisoFacebook != null || _avisoTiktok != null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.businessSettingsService.updateContactInfo(
        fullName: _nameController.text.trim(),
        businessType: tipoDeNegocioAGuardar(
          original: _tipoOriginal,
          escrito: _businessTypeController.text,
        ),
        contactPhone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        instagram: _instagramController.text.trim(),
        facebook: _facebookController.text.trim(),
        tiktok: _tiktokController.text.trim(),
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del negocio actualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre de contacto titular',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _businessTypeController,
          decoration: const InputDecoration(
            labelText: 'Tipo de negocio',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        // D-321: el usuario o el enlace del perfil, nunca el nombre de la
        // cuenta; si no, el botón de la página manda a una cuenta que no existe.
        TextField(
          controller: _instagramController,
          decoration: InputDecoration(
            labelText: 'Instagram',
            hintText: '@naguaradeunas',
            helperText: 'Tu usuario o el enlace de tu perfil',
            errorText: _avisoInstagram,
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _facebookController,
          decoration: InputDecoration(
            labelText: 'Facebook',
            hintText: 'facebook.com/tusalon',
            helperText: 'El enlace de tu página: en Facebook, ⋯ → Copiar enlace',
            helperMaxLines: 2,
            errorText: _avisoFacebook,
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        // D-319: lo pidió David, el primer cliente real.
        TextField(
          controller: _tiktokController,
          decoration: InputDecoration(
            labelText: 'TikTok',
            hintText: '@tusalon',
            helperText: 'Tu @usuario o el enlace: en TikTok, Perfil → compartir → Copiar enlace',
            helperMaxLines: 2,
            errorText: _avisoTiktok,
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: const Text('Guardar cambios'),
          ),
        ),
      ],
    );
  }
}

/// Los datos de la sede en la que estás parado (D-242, paso 9.43).
///
/// POR QUÉ EXISTE, Y POR QUÉ LA DIRECCIÓN YA NO ESTÁ ARRIBA
///
/// Hasta hoy, «Datos del negocio» traía una casilla de *Dirección física* que
/// leía y escribía **siempre la sede principal**, mirases la sede que mirases:
///
///     get_business_settings():      left join branches ... is_primary = true
///     update_tenant_contact_info(): update branches ... is_primary = true
///
/// Con un solo local no se nota. Con dos, estando dentro de la segunda, la
/// pantalla te enseñaba la dirección de la primera — y si la corregías,
/// **sobrescribías la de la primera sin aviso**. El propietario lo destapó con
/// dos capturas que decían direcciones distintas para la misma sede.
///
/// Por eso la dirección se mudó aquí en vez de duplicarse: mientras dos
/// casillas escriban `branches.address`, una pisa a la otra.
///
/// Esta tarjeta se rehace sola al cambiar de sede, porque [ConfiguracionPage]
/// lleva `ValueKey('settings-<sede>')` y se remonta entera (D-201).
class _DatosDeEstaSedeCard extends StatefulWidget {
  const _DatosDeEstaSedeCard({required this.branchId});

  final String branchId;

  @override
  State<_DatosDeEstaSedeCard> createState() => _DatosDeEstaSedeCardState();
}

class _DatosDeEstaSedeCardState extends State<_DatosDeEstaSedeCard> {
  final BranchesService _branchesService = const BranchesService();
  late Future<BranchInfo?> _future;

  @override
  void initState() {
    super.initState();
    // En initState y no en el build: un FutureBuilder que crea su futuro al
    // construirse lo relanza en cada repintado (D-211).
    _future = _branchesService.getBranchInfo(widget.branchId);
  }

  void _recargar() {
    setState(() {
      _future = _branchesService.getBranchInfo(widget.branchId);
    });
  }

  Future<void> _editar(BranchInfo sede) async {
    // Hallazgo AK: guarda desde dentro y, si el servidor rechaza —un correo
    // sin arroba—, se queda abierto con los siete campos escritos. Es el
    // mismo formulario que usa el Panel de plataforma: estaba copiado dos
    // veces, con el mismo fallo en las dos.
    final guardado = await mostrarDialogoDatosDeSede(
      context,
      nombreSede: sede.branchName,
      aviso:
          'Son los datos de ESTA sede. Si tienes más de una, cada una lleva '
          'los suyos. Lo que borres aquí se borra.',
      actuales: DatosDeSede(
        managerName: sede.managerName,
        contactEmail: sede.contactEmail,
        contactPhone: sede.contactPhone,
        whatsapp: sede.whatsapp,
        address: sede.address,
        city: sede.city,
        department: sede.department,
      ),
      // `widget.branchId`, no la principal: D-242.
      guardar: (d) => _branchesService.updateBranchInfo(
        branchId: widget.branchId,
        managerName: d.managerName,
        contactEmail: d.contactEmail,
        contactPhone: d.contactPhone,
        whatsapp: d.whatsapp,
        address: d.address,
        city: d.city,
        department: d.department,
      ),
    );

    if (guardado && mounted) _recargar();
  }

  Widget _fila(String etiqueta, String? valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (valor ?? '').isEmpty ? 'Sin registrar' : valor!,
              style: TextStyle(
                fontSize: 13,
                color: (valor ?? '').isEmpty
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BranchInfo?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard(mensaje: 'Cargando los datos de la sede...');
        }
        if (snapshot.hasError || snapshot.data == null) {
          // Sin nombrarle funciones de la base a nadie (D-208).
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No pudimos cargar los datos de esta sede ahora mismo.',
                style: TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          );
        }

        final sede = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sede.isPrimary
                          ? Icons.home_outlined
                          : Icons.storefront_outlined,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sede.branchName +
                            (sede.isPrimary ? '  ·  sede principal' : ''),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editar(sede),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (!sede.tieneDatos)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Esta sede todavía no tiene datos propios. Sirven para '
                      'que quien llame o escriba llegue a la sede correcta, y '
                      'para que la dirección de cada local sea la suya.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                _fila('Encargado:', sede.managerName),
                _fila('Correo:', sede.contactEmail),
                _fila('Teléfono:', sede.contactPhone),
                _fila('WhatsApp:', sede.whatsapp),
                _fila('Dirección:', sede.address),
                _fila('Ciudad:', sede.city),
                _fila('Departamento:', sede.department),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Único punto de entrada a [CreateBranchDialog] tras retirarlo del header
/// (D-161): la gestión de sedes vive ordenadamente dentro de Configuración.
class _SedesCard extends StatelessWidget {
  const _SedesCard({required this.onSedeCreada});

  final VoidCallback onSedeCreada;

  Future<void> _openCreateBranchDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateBranchDialog(),
    );

    if (created != true || !context.mounted) return;

    // El mensajero se resuelve ANTES de recargar: `onSedeCreada` reconstruye
    // el árbol desde la raíz y este `context` deja de estar montado. El aviso
    // sí sobrevive, porque el `ScaffoldMessenger` está por encima.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sede creada. Ya aparece en el selector de sedes, arriba: cámbiate '
          'a ella para asignarle servicios y estilistas.',
        ),
        duration: Duration(seconds: 6),
      ),
    );

    // D-238, regla 16-ter: el aviso de arriba solo es verdad DESPUÉS de esto.
    // Sin recargar, la sede existe en la base y no existe en la pantalla.
    onSedeCreada();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.add_business_outlined, color: AppColors.brand),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Agrega una nueva sede de tu negocio.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            OutlinedButton(
              onPressed: () => _openCreateBranchDialog(context),
              child: const Text('Agregar sede'),
            ),
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

/// Lo que explica la tarjeta del enlace. D-312: sin caja, la reserva no
/// queda pendiente; queda confirmada.
String textoDeLaTarjetaDeReserva({required bool citasNacenConfirmadas}) =>
    citasNacenConfirmadas
    ? 'Compártelo en Instagram, WhatsApp o un código QR. Tus clientes ven '
          'tu página y reservan sin crear cuenta ni contraseña, y la cita '
          'queda confirmada en tu agenda.'
    : 'Compártelo en Instagram, WhatsApp o un código QR. Tus clientes ven '
          'tu página y reservan sin crear cuenta ni contraseña; la reserva '
          'queda pendiente de tu confirmación.';

/// **Tu enlace** (D-318, 07-oct): una sola tarjeta donde antes había dos,
/// *Enlace web de tu negocio* (D-164) y *Reserva pública* (D-313), que en un
/// salón de una sede daban el mismo enlace. La usan Configuración y *Mi
/// vitrina*.
///
/// El enlace es la página del salón, `salonymas.com/<nombre>`; si todavía no
/// se conoce, el directo de la sede, que funciona igual. En una sede que no
/// es la principal sale además el directo de esa sede, porque la página del
/// salón agenda siempre en la principal (D-313).
///
/// **Sin "Modificar enlace", a propósito** (decisión del propietario, 07-oct):
/// al cambiarlo, los enlaces y QR ya repartidos dejaban de funcionar, y la
/// dirección vieja quedaba libre para que otro salón la tomara. Cambiarlo
/// queda para el Panel de la plataforma, con la dirección vieja llevando a la
/// nueva (buzón, I-24).
class TuEnlaceCard extends StatelessWidget {
  const TuEnlaceCard({
    super.key,
    required this.branchId,
    this.slugDelSalon,
    this.nombreDelSalon,
    this.citasNacenConfirmadas = false,
    this.esSedePrincipal = false,
    this.origen,
  });

  final String branchId;
  final String? slugDelSalon;
  final String? nombreDelSalon;
  final bool citasNacenConfirmadas;
  final bool esSedePrincipal;

  /// Solo lo pasan las pruebas, como en [enlaceDeReservaDeSede].
  final String? origen;

  String get _enlaceDeLaSede => enlaceDeReservaDeSede(branchId, origen: origen);

  String get _enlace {
    final slug = slugDelSalon?.trim() ?? '';
    return slug.isEmpty
        ? _enlaceDeLaSede
        : enlaceDeLaPaginaDelSalon(slug, origen: origen);
  }

  Future<void> _copiar(BuildContext context, String enlace) async {
    await Clipboard.setData(ClipboardData(text: enlace));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  Future<void> _compartirEnWhatsApp() async {
    final nombre = nombreDelSalon?.trim() ?? '';
    final message = nombre.isEmpty
        ? 'Reserva tu cita aquí 👉 $_enlace'
        : 'Visita la página de $nombre 👉 $_enlace';
    final uri = Uri.https('wa.me', '/', {'text': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _cajaDelEnlace(BuildContext context, String enlace, {bool tenue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              enlace,
              style: TextStyle(
                fontSize: 14,
                color: tenue ? AppColors.textSecondary : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Copiar enlace',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copiar(context, enlace),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              textoDeLaTarjetaDeReserva(
                citasNacenConfirmadas: citasNacenConfirmadas,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _cajaDelEnlace(context, _enlace),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _compartirEnWhatsApp,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: AppColors.whatsapp,
                  ),
                  label: const Text('Compartir en WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.whatsapp,
                  ),
                ),
                // D-319: el texto de arriba habla de un código QR; aquí se
                // ve y se descarga para imprimirlo.
                OutlinedButton.icon(
                  onPressed: () => mostrarCodigoQr(
                    context,
                    enlace: _enlace,
                    nombreDelSalon: nombreDelSalon,
                  ),
                  icon: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('Código QR'),
                ),
              ],
            ),
            // Sin la dirección del salón, el de arriba ya es el de la sede.
            if (!esSedePrincipal && (slugDelSalon?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Reservar directo en esta sede',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _cajaDelEnlace(context, _enlaceDeLaSede, tenue: true),
            ],
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
            // Hallazgo AJ. Este aviso es el sitio donde el dueño se entera de
            // que la cifra con la que se le está pagando a su equipo no la
            // eligió él. Va arriba del todo, antes que los datos, porque
            // debajo de ellos parecería una nota al pie.
            if (!policy.confirmada) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Esta comisión viene de fábrica: nadie la ha confirmado. '
                  'Con ella ya se está calculando lo que gana cada persona de '
                  'tu equipo. Ábrela y guárdala, aunque la dejes igual.',
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                label: Text(
                  policy.confirmada ? 'Editar comisión' : 'Revisar y confirmar',
                ),
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
              return const Text(
                'No se pudieron cargar los servicios. Revisa tu conexión a internet o intenta nuevamente más tarde.',
                style: TextStyle(color: Colors.red),
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
        // CC (D-302): num.tryParse toma el punto de miles como decimal: "35.000"
        // se guardaba como 35, sin aviso. CifraEscrita lo lee en pesos, y lo que
        // no se entiende da null, que es el error que esta pantalla ya enseñaba.
        final fixed = CifraEscrita.pesos(fixedController.text).valor;

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
    // CC (D-302): num.tryParse toma el punto de miles como decimal: "35.000"
    // se guardaba como 35, sin aviso. CifraEscrita lo lee en pesos, y lo que
    // no se entiende da null, que es el error que esta pantalla ya enseñaba.
    final fixed = CifraEscrita.pesos(fixedController.text).valor;

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

/// Tarjeta de gestión del consecutivo de ventas y Resolución DIAN por sede (D-150 / D-156).
class SaleNumberingCard extends StatelessWidget {
  final BranchSaleNumbering numbering;
  final bool isOwner;
  final VoidCallback onEdit;

  const SaleNumberingCard({
    super.key,
    required this.numbering,
    required this.isOwner,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consecutivo de ventas por sede',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Separa el número de cita operativa del número contable emitido al cobrar.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Ajustar numeración'),
                  ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _InfoBlock(
                  label: 'Próxima venta',
                  value: numbering.previewNextCode,
                  highlight: true,
                ),
                _InfoBlock(
                  label: 'Prefijo actual',
                  value: numbering.prefix.isEmpty ? '(Sin prefijo)' : numbering.prefix,
                ),
                _InfoBlock(
                  label: 'Siguiente número',
                  value: '#${numbering.nextNumber}',
                ),
                _InfoBlock(
                  label: 'Última venta emitida',
                  value: numbering.lastEmittedNumber > 0
                      ? '#${numbering.lastEmittedNumber}'
                      : 'Ninguna aún',
                ),
                _InfoBlock(
                  label: 'Relleno de ceros',
                  value: '${numbering.padding} dígitos',
                ),
              ],
            ),
            if (numbering.hasResolution) ...[
              const Divider(height: 24),
              Text(
                'Resolución DIAN configurada',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandDeep,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _InfoBlock(
                    label: 'N° Resolución',
                    value: numbering.resolutionNumber!,
                  ),
                  if (numbering.resolutionDate != null)
                    _InfoBlock(
                      label: 'Fecha de expedición',
                      value: numbering.resolutionDate!.toIso8601String().split('T').first,
                    ),
                  if (numbering.rangeFrom != null && numbering.rangeTo != null)
                    _InfoBlock(
                      label: 'Rango autorizado',
                      value: '${numbering.rangeFrom} al ${numbering.rangeTo}',
                    ),
                  if (numbering.validUntil != null)
                    _InfoBlock(
                      label: 'Vigente hasta',
                      value: numbering.validUntil!.toIso8601String().split('T').first,
                    ),
                ],
              ),
              if (numbering.isNearLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.stateToCollect.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.stateToCollect.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.stateToCollect, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Atención: Quedan menos de 100 números para agotar el rango autorizado en la DIAN.',
                            style: TextStyle(fontSize: 13, color: AppColors.stateToCollect, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoBlock({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 15,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.brandDeep : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo interactivo para ajustar prefijo, consecutivo y Resolución DIAN por sede.
class _EditSaleNumberingDialog extends StatefulWidget {
  final BranchSaleNumbering numbering;
  final BranchSaleNumberingService branchSaleNumberingService;

  const _EditSaleNumberingDialog({
    required this.numbering,
    required this.branchSaleNumberingService,
  });

  @override
  State<_EditSaleNumberingDialog> createState() =>
      _EditSaleNumberingDialogState();
}

class _EditSaleNumberingDialogState extends State<_EditSaleNumberingDialog> {
  late final prefixController = TextEditingController(
    text: widget.numbering.prefix,
  );
  late final nextNumberController = TextEditingController(
    text: widget.numbering.nextNumber.toString(),
  );
  late final paddingController = TextEditingController(
    text: widget.numbering.padding.toString(),
  );
  late final resolutionNumberController = TextEditingController(
    text: widget.numbering.resolutionNumber ?? '',
  );
  late final rangeFromController = TextEditingController(
    text: widget.numbering.rangeFrom?.toString() ?? '',
  );
  late final rangeToController = TextEditingController(
    text: widget.numbering.rangeTo?.toString() ?? '',
  );

  DateTime? resolutionDate;
  DateTime? validUntil;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    resolutionDate = widget.numbering.resolutionDate;
    validUntil = widget.numbering.validUntil;
  }

  @override
  void dispose() {
    prefixController.dispose();
    nextNumberController.dispose();
    paddingController.dispose();
    resolutionNumberController.dispose();
    rangeFromController.dispose();
    rangeToController.dispose();
    super.dispose();
  }

  String get previewCode {
    final prefix = prefixController.text.trim();
    final nextNum = int.tryParse(nextNumberController.text.trim()) ?? 1;
    final pad = int.tryParse(paddingController.text.trim()) ?? 7;
    final cleanPad = pad.clamp(1, 12);
    return '$prefix${nextNum.toString().padLeft(cleanPad, '0')}';
  }

  Future<void> _save() async {
    final prefix = prefixController.text.trim();
    final nextNumber = int.tryParse(nextNumberController.text.trim());
    final padding = int.tryParse(paddingController.text.trim());
    final resolutionNumber = resolutionNumberController.text.trim();
    final rangeFrom = int.tryParse(rangeFromController.text.trim());
    final rangeTo = int.tryParse(rangeToController.text.trim());

    if (nextNumber == null || nextNumber < 1) {
      setState(() => errorMessage = 'El siguiente número debe ser mayor o igual a 1.');
      return;
    }

    if (nextNumber <= widget.numbering.lastEmittedNumber) {
      setState(() => errorMessage =
          'El siguiente número no puede ser menor o igual al último número ya emitido (#${widget.numbering.lastEmittedNumber}).');
      return;
    }

    if (padding == null || padding < 1 || padding > 12) {
      setState(() => errorMessage = 'La cantidad de dígitos debe estar entre 1 y 12.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.branchSaleNumberingService.updateBranchSaleNumbering(
        prefix: prefix,
        nextNumber: nextNumber,
        padding: padding,
        resolutionNumber: resolutionNumber.isEmpty ? null : resolutionNumber,
        resolutionDate: resolutionDate,
        rangeFrom: rangeFrom,
        rangeTo: rangeTo,
        validUntil: validUntil,
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
      title: const Text('Configurar numeración de ventas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa del próximo recibo:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previewCode,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: prefixController,
              decoration: const InputDecoration(
                labelText: 'Prefijo (ej. VTA-, POS-, FJ-)',
                hintText: 'VTA-',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nextNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Siguiente número a emitir',
                helperText: widget.numbering.lastEmittedNumber > 0
                    ? 'Último emitido: #${widget.numbering.lastEmittedNumber}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: paddingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Relleno de ceros (entre 1 y 12 dígitos)',
                hintText: '7',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text(
              'Resolución DIAN (Opcional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDeep,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: resolutionNumberController,
              decoration: const InputDecoration(
                labelText: 'Número de resolución DIAN',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rangeFromController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rango desde'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rangeToController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rango hasta'),
                  ),
                ),
              ],
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: AppColors.danger)),
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
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar configuración'),
        ),
      ],
    );
  }
}

/// Tarjeta informativa de políticas de fotos de trabajo (D-156).
class _PhotoPolicyCard extends StatelessWidget {
  const _PhotoPolicyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipos de foto de trabajo y portafolio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.brandDeep,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las fotos de evidencia tomadas en cada cita quedan archivadas y vinculadas al ticket.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            const _SettingsLine(
              label: 'Tipos activos',
              value: 'Antes, Después, Final y Portafolio',
            ),
            const _SettingsLine(
              label: 'Almacén privado',
              value: 'work-photos-private (hasta aprobación)',
            ),
            const _SettingsLine(
              label: 'Almacén público',
              value: 'work-photos (fotos aprobadas en portafolio)',
            ),
            const _SettingsLine(
              label: 'Privacidad',
              value: 'Aprobación explícita por la dueña requerida para publicación externa',
            ),
          ],
        ),
      ),
    );
  }
}

/// El tiempo de volver por defecto del salón (D-314, paso 4B): manda en los
/// servicios que no tienen el suyo. Nace en 45 días, la regla de "En riesgo".
class TiempoDeVolverDelSalonCard extends StatefulWidget {
  const TiempoDeVolverDelSalonCard({super.key, required this.branchId});

  final String branchId;

  @override
  State<TiempoDeVolverDelSalonCard> createState() =>
      _TiempoDeVolverDelSalonCardState();
}

class _TiempoDeVolverDelSalonCardState
    extends State<TiempoDeVolverDelSalonCard> {
  late final InvitarAVolverService _servicio = InvitarAVolverService(
    branchId: widget.branchId,
  );
  final TextEditingController _controller = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _servicio
        .tiempos()
        .then((t) {
          if (!mounted) return;
          setState(() {
            _controller.text = t.delSalon.toString();
            _cargando = false;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _cargando = false);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final avisos = ScaffoldMessenger.of(context);
    final dias = int.tryParse(_controller.text.trim());
    if (dias == null || dias < 1 || dias > 365) {
      avisos.showSnackBar(
        const SnackBar(content: Text('Escribe un número de 1 a 365 días.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await _servicio.fijarTiempoDelSalon(dias);
      avisos.showSnackBar(
        SnackBar(content: Text('Listo: se invita a volver a los $dias días.')),
      );
    } catch (error) {
      avisos.showSnackBar(SnackBar(content: Text(mensajeParaLaClienta(error))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
              'Cuántos días después de su última visita se le sugiere invitar '
              'a una clienta a volver. Cada servicio puede tener el suyo en '
              'Servicios (un rubber, un tinte); este es para los que no lo '
              'tienen.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _controller,
                    enabled: !_cargando,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Días',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _cargando || _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
