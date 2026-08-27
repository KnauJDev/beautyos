import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_profile.dart';
import 'models/branch_context.dart';
import 'models/pending_invitation.dart';
import 'models/tenant_subscription_status.dart';
import 'services/branch_context_service.dart';
import 'services/epayco_checkout_service.dart';
import 'services/monitoreo_service.dart';
import 'services/my_profile_service.dart';
import 'services/team_invitations_service.dart';
import 'services/tenant_subscription_service.dart';

import 'pages/accept_invitation_page.dart';
import 'pages/auth_gate.dart';
import 'pages/authenticated_router.dart';
import 'pages/complete_tenant_setup_page.dart';
import 'pages/public_booking_page.dart';
import 'pages/public_plans_page.dart';
import 'pages/public_review_page.dart';
import 'pages/tenant_approval_status_page.dart';
import 'pages/terms_and_privacy_page.dart';
import 'pages/agenda_page.dart';
import 'pages/clients_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/my_commission_summary_page.dart';
import 'pages/my_stylist_agenda_page.dart';
import 'pages/my_stylist_reviews_page.dart';
import 'pages/my_stylist_work_photos_page.dart';
import 'pages/work_photos_page.dart';
import 'widgets/security_settings_dialog.dart';
import 'theme/app_theme.dart';
import 'widgets/update_banner.dart';
import 'pages/reviews_page.dart';
import 'pages/purchases_page.dart';
import 'pages/expenses_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/services_page.dart';
import 'pages/stylists_page.dart';
import 'pages/tickets_page.dart';
import 'pages/users_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eogppgbdnwxdtcbctaol.supabase.co',
    publishableKey: 'sb_publishable_3MOOddcfu6tga68hPr06gw_IdEJ74Pc',
  );

  // El monitoreo envuelve a la aplicacion entera para poder capturar tambien
  // lo que se rompa al arrancar (D-115). Configurado para **no enviar ningun
  // dato personal**: ver `MonitoreoService`.
  await MonitoreoService.arrancar(() => const BeautyOSApp());
}

class BeautyOSApp extends StatelessWidget {
  const BeautyOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reserva publica (D-005): enlace sin sesion, ej. "?reservar=<branch_id>".
    // Se resuelve antes de AuthGate a proposito: un cliente anonimo nunca
    // debe pasar por la pantalla de login para reservar.
    final publicBranchId = Uri.base.queryParameters['reservar'];
    // Resena publica (D-058): enlace sin sesion, ej. "?resena=<ticket_id>".
    // Mismo motivo: un cliente anonimo nunca debe pasar por login.
    final publicReviewTicketId = Uri.base.queryParameters['resena'];
    // Planes publicos (Paso 3.8 / D-140): enlace sin sesion, ej. "?planes=1".
    final isPublicPlans = Uri.base.queryParameters.containsKey('planes') ||
        Uri.base.queryParameters.containsKey('pricing');
    // Terminos y Privacidad (Paso 3.3): enlace sin sesion, ej. "?terminos=1"
    // o "?privacidad=1". Cada uno abre directo en su pestana.
    final isPublicTerms = Uri.base.queryParameters.containsKey('terminos') ||
        Uri.base.queryParameters.containsKey('terms');
    final isPublicPrivacy =
        Uri.base.queryParameters.containsKey('privacidad') ||
            Uri.base.queryParameters.containsKey('privacy');

    // Un solo sitio decide el aspecto de toda la aplicacion (D-102). El tema
    // del negocio no se conoce al arrancar -- llega con los datos de la sede o
    // de la reserva publica --, asi que `MaterialApp` se reconstruye cuando
    // `AppBrand.aplicar()` cambia la paleta (D-109).
    return ValueListenableBuilder<BrandPalette>(
      valueListenable: AppBrand.activo,
      builder: (context, palette, _) {
        final Widget home;
        if (publicBranchId != null && publicBranchId.trim().isNotEmpty) {
          home = PublicBookingPage(branchId: publicBranchId.trim());
        } else if (publicReviewTicketId != null &&
            publicReviewTicketId.trim().isNotEmpty) {
          home = PublicReviewPage(ticketId: publicReviewTicketId.trim());
        } else if (isPublicPlans) {
          home = const PublicPlansPage();
        } else if (isPublicTerms) {
          home = const TermsAndPrivacyPage(initialTab: 0);
        } else if (isPublicPrivacy) {
          home = const TermsAndPrivacyPage(initialTab: 1);
        } else {
          home = const AuthGate(
            authenticatedChild: AuthenticatedRouter(
              businessApp: BeautyOSHome(),
            ),
          );
        }

        return MaterialApp(
          title: 'Salón y Más',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: home,
        );
      },
    );
  }
}

class BeautyOSHome extends StatefulWidget {
  const BeautyOSHome({super.key});

  @override
  State<BeautyOSHome> createState() => _BeautyOSHomeState();
}

class _HomeContextData {
  const _HomeContextData({
    required this.profile,
    required this.branches,
    this.pendingInvitation,
    this.subscriptionStatus,
  });

  final MyProfile? profile;
  final List<BranchContext> branches;
  final PendingInvitation? pendingInvitation;
  final TenantSubscriptionStatus? subscriptionStatus;
}

class _BeautyOSHomeState extends State<BeautyOSHome> {
  int selectedIndex = 0;

  /// Ticket que Agenda pidio abrir en la pestana de Tickets (D-163). Se
  /// consume una sola vez: `TicketsPage` avisa con `onTicketOpened` y este
  /// campo vuelve a null para no reabrir el mismo ticket despues.
  String? _pendingOpenTicketId;

  final MyProfileService myProfileService = const MyProfileService();
  final BranchContextService branchContextService =
      const BranchContextService();
  final TeamInvitationsService teamInvitationsService =
      const TeamInvitationsService();
  final TenantSubscriptionService tenantSubscriptionService =
      const TenantSubscriptionService();
  final EpaycoCheckoutService epaycoService = const EpaycoCheckoutService();

  late Future<_HomeContextData> homeContextFuture;
  BranchContext? selectedBranch;

  @override
  void initState() {
    super.initState();
    homeContextFuture = _loadHomeContext();
  }

  Future<_HomeContextData> _loadHomeContext() async {
    // Si la URL contiene una confirmación de pago de ePayco (ej. ?ref_payco=...), verificarla
    final refPayco = Uri.base.queryParameters['ref_payco'];
    if (refPayco != null && refPayco.isNotEmpty) {
      try {
        await Supabase.instance.client.functions.invoke(
          'verify-epayco-transaction',
          body: {'ref_payco': refPayco},
        );
      } catch (e, st) {
        MonitoreoService.reportarError(
          e,
          st,
          motivo: 'Fallo al verificar confirmación ePayco $refPayco',
        );
      }
    }

    final profile = await myProfileService.getMyProfile();

    if (profile == null) {
      final pendingInvitation = await teamInvitationsService
          .getMyPendingInvitation();
      return _HomeContextData(
        profile: null,
        branches: const [],
        pendingInvitation: pendingInvitation,
      );
    }

    // Consultar estado de aprobación / suscripción del negocio (D-125)
    final subscriptionStatus = await tenantSubscriptionService
        .getMyTenantSubscriptionStatus();

    if (subscriptionStatus != null &&
        (subscriptionStatus.isPending || subscriptionStatus.isRejected)) {
      return _HomeContextData(
        profile: profile,
        branches: const [],
        subscriptionStatus: subscriptionStatus,
      );
    }

    final branches = await branchContextService.getAccessibleBranches();

    // Quien y de que negocio, sin decir nombres (D-115). Sirve para saber si un
    // fallo le pasa a una persona o a un negocio entero.
    await MonitoreoService.anotarContexto(
      userId: Supabase.instance.client.auth.currentUser?.id,
      rol: profile.role,
      tenantId: branches.isEmpty ? null : branches.first.tenantId,
    );

    if (branches.isNotEmpty) {
      final inicial = _initialBranch(branches);
      AppBrand.aplicar(inicial.tenantThemeKey, inicial.tenantBrandColor);
    }

    return _HomeContextData(
      profile: profile,
      branches: branches,
      subscriptionStatus: subscriptionStatus,
    );
  }

  Future<void> signOut() async {
    AppBrand.aplicar(null, null);
    await MonitoreoService.olvidarContexto();
    await Supabase.instance.client.auth.signOut();
  }

  List<BeautyModule> _modulesForProfile(
    MyProfile? profile,
    BranchContext branch,
    List<BranchContext> branches,
  ) {
    final role = profile?.role ?? 'client';

    final modules = <BeautyModule>[
      // ======================================================================
      // 1. OPERACIÓN DIARIA (La recepcionista y la dueña trabajan aquí)
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Agenda',
          Icons.calendar_month_outlined,
          category: BeautyCategory.operacion,
        ),
        page: AgendaPage(
          key: ValueKey('agenda-${branch.branchId}'),
          branchId: branch.branchId,
          // Agenda y Tickets comparten exactamente los mismos allowedRoles
          // y son adyacentes en esta lista: Tickets siempre queda en el
          // indice inmediatamente siguiente al de Agenda, para cualquier
          // rol que vea Agenda (D-163).
          onOpenTicket: (ticketId) {
            setState(() {
              _pendingOpenTicketId = ticketId;
              selectedIndex = selectedIndex + 1;
            });
          },
        ),
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Tickets & Caja',
          Icons.confirmation_number_outlined,
          category: BeautyCategory.operacion,
        ),
        page: TicketsPage(
          key: ValueKey('tickets-${branch.branchId}'),
          branchId: branch.branchId,
          isOwnerOrAdmin: role == 'owner' || role == 'admin',
          openTicketId: _pendingOpenTicketId,
          onTicketOpened: () => setState(() => _pendingOpenTicketId = null),
        ),
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      const BeautyModule(
        section: BeautySection(
          'Clientes',
          Icons.people_outline,
          category: BeautyCategory.operacion,
        ),
        page: ClientesPage(),
        allowedRoles: <String>{'owner', 'admin', 'assistant'},
      ),

      // ======================================================================
      // ESTILISTA PERSONAL
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Mi agenda',
          Icons.event_available_outlined,
          category: BeautyCategory.operacion,
        ),
        page: MyStylistAgendaPage(
          key: ValueKey('my-agenda-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mis fotos',
          Icons.photo_library_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: MyStylistWorkPhotosPage(
          key: ValueKey('my-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mis reseñas',
          Icons.star_outline,
          category: BeautyCategory.portafolio,
        ),
        page: MyStylistReviewsPage(
          key: ValueKey('my-reviews-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mi panel financiero',
          Icons.payments_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: MyCommissionSummaryPage(
          key: ValueKey('my-commissions-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),

      // ======================================================================
      // 2. FINANZAS Y GESTIÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Dashboard',
          Icons.dashboard_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: DashboardPage(
          key: const ValueKey('dashboard'),
          branchId: branch.branchId,
          branches: branches,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Reportes',
          Icons.bar_chart_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: ReportesPage(
          key: ValueKey('reports-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Inventario',
          Icons.inventory_2_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: InventarioPage(
          key: ValueKey('inventory-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Compras',
          Icons.shopping_cart_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: ComprasPage(
          key: ValueKey('purchases-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Gastos',
          Icons.payments_outlined,
          category: BeautyCategory.finanzas,
        ),
        page: GastosPage(
          key: ValueKey('expenses-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),

      // ======================================================================
      // 3. PORTAFOLIO Y REPUTACIÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Fotos de trabajos',
          Icons.photo_library_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: FotosTrabajosPage(
          key: ValueKey('work-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Reseñas',
          Icons.rate_review_outlined,
          category: BeautyCategory.portafolio,
        ),
        page: ResenasPage(
          key: ValueKey('reviews-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),

      // ======================================================================
      // 4. CATÁLOGO Y AJUSTES DEL SALÓN
      // ======================================================================
      BeautyModule(
        section: const BeautySection(
          'Servicios',
          Icons.content_cut_outlined,
          category: BeautyCategory.sistema,
        ),
        page: ServiciosPage(
          key: ValueKey('services-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Estilistas',
          Icons.badge_outlined,
          category: BeautyCategory.sistema,
        ),
        page: EstilistasPage(
          key: ValueKey('stylists-${branch.branchId}'),
          branchId: branch.branchId,
          tenantId: branch.tenantId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Usuarios',
          Icons.manage_accounts_outlined,
          category: BeautyCategory.sistema,
        ),
        page: UsuariosPage(
          key: ValueKey('users-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Configuración',
          Icons.settings_outlined,
          category: BeautyCategory.sistema,
        ),
        page: ConfiguracionPage(
          key: ValueKey('settings-${branch.branchId}'),
          branchId: branch.branchId,
          isOwner: role == 'owner',
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
    ];

    return modules
        .where((module) => module.canAccess(role))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeContextData>(
      future: homeContextFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos cargar las sedes autorizadas.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final homeContext = snapshot.data;
        final profile = homeContext?.profile;
        final subscriptionStatus = homeContext?.subscriptionStatus;
        final branches = homeContext?.branches ?? const <BranchContext>[];

        if (profile == null) {
          final pendingInvitation = homeContext?.pendingInvitation;

          if (pendingInvitation != null) {
            return AcceptInvitationPage(
              invitation: pendingInvitation,
              onAccepted: () {
                setState(() {
                  homeContextFuture = _loadHomeContext();
                });
              },
            );
          }

          return CompleteTenantSetupPage(
            onCompleted: () {
              setState(() {
                homeContextFuture = _loadHomeContext();
              });
            },
          );
        }

        if (subscriptionStatus != null &&
            (subscriptionStatus.isPending || subscriptionStatus.isRejected)) {
          return TenantApprovalStatusPage(
            status: subscriptionStatus,
            onRefresh: () async {
              setState(() {
                homeContextFuture = _loadHomeContext();
              });
            },
          );
        }

        if (branches.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: const Center(
              child: Text('Tu usuario no tiene una sede operativa asignada.'),
            ),
          );
        }

        final branch = selectedBranch ?? _initialBranch(branches);
        final modules = _modulesForProfile(profile, branch, branches);

        if (modules.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: const Text('Salón y Más'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: const Center(
              child: Text('Tu usuario no tiene módulos asignados.'),
            ),
          );
        }

        final currentIndex = selectedIndex >= modules.length
            ? 0
            : selectedIndex;
        final sections = modules
            .map((module) => module.section)
            .toList(growable: false);
        final pages = modules
            .map((module) => module.page)
            .toList(growable: false);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;

            return Scaffold(
              backgroundColor: AppColors.brandSurface,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: AppBar(
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    titleSpacing: isWide ? AppSpacing.lg : AppSpacing.md,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Isotipo / Logo
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brand,
                                AppColors.brandDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: branch.tenantLogoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      branch.tenantLogoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (isWide) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                branch.tenantName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandDeep,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'BeautyOS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.lg),
                        ],
                        // Selector de Sede Pill
                        _BranchSelectorPill(
                          branches: branches,
                          selectedBranch: branch,
                          compact: !isWide,
                          onSelected: (value) {
                            if (value.branchId == branch.branchId) return;
                            AppBrand.aplicar(
                              value.tenantThemeKey,
                              value.tenantBrandColor,
                            );
                            setState(() {
                              selectedBranch = value;
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      // Botón de Acción Rápida Global
                      if (profile.role == 'owner' ||
                          profile.role == 'admin' ||
                          profile.role == 'assistant')
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: FilledButton.icon(
                            onPressed: () =>
                                openCreateAppointmentDialog(context, branch.branchId),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(isWide ? 'Nueva Cita' : 'Cita'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: isWide ? AppSpacing.md : AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Badge de Prueba / Gracia discreto
                      if (isWide &&
                          (profile.role == 'owner' || profile.role == 'admin'))
                        _TrialHeaderBadge(
                          subscriptionStatus: subscriptionStatus,
                          onRefresh: () {
                            setState(() {
                              homeContextFuture = _loadHomeContext();
                            });
                          },
                        ),

                      // Avatar de Usuario & Menú de Perfil
                      _UserProfileMenu(
                        profile: profile,
                        onSignOut: signOut,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              body: Column(
                children: [
                  const UpdateBanner(),
                  Expanded(
                    child: Row(
                      children: [
                        if (isWide)
                          _CategorizedSideMenu(
                            sections: sections,
                            selectedIndex: currentIndex,
                            onDestinationSelected: (index) {
                              setState(() {
                                selectedIndex = index;
                              });
                            },
                          ),
                        Expanded(
                          child: IndexedStack(
                            index: currentIndex,
                            children: pages,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isWide
                  ? null
                  : _MobileNavBar(
                      sections: sections,
                      currentIndex: currentIndex,
                      onSelected: (index) {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      onSignOut: signOut,
                    ),
            );
          },
        );
      },
    );
  }

  BranchContext _initialBranch(List<BranchContext> branches) {
    for (final branch in branches) {
      if (branch.isPrimary) {
        return branch;
      }
    }
    return branches.first;
  }
}

// ============================================================================
// ENUM DE CATEGORÍAS SEMÁNTICAS
// ============================================================================
enum BeautyCategory {
  operacion('OPERACIÓN'),
  finanzas('FINANZAS Y GESTIÓN'),
  portafolio('PORTAFOLIO'),
  sistema('CATÁLOGO Y AJUSTES');

  const BeautyCategory(this.label);
  final String label;
}

class BeautySection {
  final String title;
  final IconData icon;
  final BeautyCategory category;

  const BeautySection(
    this.title,
    this.icon, {
    this.category = BeautyCategory.operacion,
  });
}

class BeautyModule {
  const BeautyModule({
    required this.section,
    required this.page,
    required this.allowedRoles,
  });

  final BeautySection section;
  final Widget page;
  final Set<String> allowedRoles;

  bool canAccess(String role) {
    return allowedRoles.contains(role);
  }
}

// ============================================================================
// SELECTOR DE SEDE TIPO PILL (MODERNO)
// ============================================================================
class _BranchSelectorPill extends StatelessWidget {
  const _BranchSelectorPill({
    required this.branches,
    required this.selectedBranch,
    required this.compact,
    required this.onSelected,
  });

  final List<BranchContext> branches;
  final BranchContext selectedBranch;
  final bool compact;
  final ValueChanged<BranchContext> onSelected;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 110 : 160),
            child: Text(
              selectedBranch.branchName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (branches.length > 1) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          ],
        ],
      ),
    );

    if (branches.length <= 1) {
      return content;
    }

    return PopupMenuButton<BranchContext>(
      tooltip: 'Cambiar de sede',
      initialValue: selectedBranch,
      onSelected: onSelected,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      itemBuilder: (context) => branches
          .map(
            (branch) => PopupMenuItem<BranchContext>(
              value: branch,
              child: Row(
                children: [
                  Icon(
                    branch.branchId == selectedBranch.branchId
                        ? Icons.check_circle_outline
                        : Icons.storefront_outlined,
                    size: 18,
                    color: branch.branchId == selectedBranch.branchId
                        ? AppColors.brand
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    branch.branchName,
                    style: TextStyle(
                      fontWeight: branch.branchId == selectedBranch.branchId
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: content,
    );
  }
}

// ============================================================================
// BADGE DE PRUEBA / GRACIA EN HEADER (MINIMALISTA)
// ============================================================================
class _TrialHeaderBadge extends StatelessWidget {
  const _TrialHeaderBadge({
    required this.subscriptionStatus,
    required this.onRefresh,
  });

  final TenantSubscriptionStatus? subscriptionStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (subscriptionStatus == null) return const SizedBox.shrink();

    final status = subscriptionStatus!;
    final epayco = const EpaycoCheckoutService();

    if (status.isGrace) {
      final days = status.graceDaysRemaining ?? 5;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => epayco.iniciarPago(context, status, onPaymentLaunched: onRefresh),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 5),
                Text(
                  '$days ${days == 1 ? "día" : "días"} de gracia · Pagar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (status.isTrialing) {
      final days = status.trialDaysRemaining;
      if (days != null && days <= 10) {
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => epayco.iniciarPago(context, status, onPaymentLaunched: onRefresh),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brandTintSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.brand),
                  const SizedBox(width: 5),
                  Text(
                    days == 0 ? 'Prueba termina hoy' : 'Prueba: $days d restantes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (status.isActive) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🟢', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
              Text(
                'Plan ${status.planName ?? "Profesional"} · Vence '
                '${_formatFechaCorta(status.currentPeriodEnd)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  static String _formatFechaCorta(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ============================================================================
// AVATAR DE USUARIO & MENÚ DE PERFIL
// ============================================================================
class _UserProfileMenu extends StatelessWidget {
  const _UserProfileMenu({
    required this.profile,
    required this.onSignOut,
  });

  final MyProfile profile;
  final Future<void> Function() onSignOut;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Perfil y cuenta',
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      onSelected: (value) {
        if (value == 'security') {
          showDialog(
            context: context,
            builder: (_) => const SecuritySettingsDialog(),
          );
        } else if (value == 'logout') {
          onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                profile.roleText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'security',
          child: Row(
            children: [
              Icon(Icons.security_outlined, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Seguridad de tu cuenta'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brandTint,
              child: Text(
                _initials(profile.fullName),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIDEBAR CATEGORIZADO MODERNO (DESKTOP)
// ============================================================================
class _CategorizedSideMenu extends StatelessWidget {
  const _CategorizedSideMenu({
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<BeautySection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // Agrupar las secciones por su categoría
    final grouped = <BeautyCategory, List<MapEntry<int, BeautySection>>>{};
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      grouped.putIfAbsent(section.category, () => []).add(MapEntry(i, section));
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 12, bottom: 6),
                child: Text(
                  entry.key.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final item in entry.value) ...[
                _SideMenuItem(
                  section: item.value,
                  isSelected: item.key == selectedIndex,
                  onTap: () => onDestinationSelected(item.key),
                ),
                const SizedBox(height: 2),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final BeautySection section;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.brandTintSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 20,
                color: isSelected ? AppColors.brand : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.brandDeep : AppColors.textStrong,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NAVEGACIÓN MÓVIL Y HOJA "MÁS" CATEGORIZADA
// ============================================================================
class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({
    required this.sections,
    required this.currentIndex,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<BeautySection> sections;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onSignOut;

  static const _visibles = 4;

  @override
  Widget build(BuildContext context) {
    final directos = sections.take(_visibles).toList();
    final enMas = sections.length > _visibles;

    final seleccionado = currentIndex < directos.length
        ? currentIndex
        : directos.length;

    return NavigationBar(
      selectedIndex: seleccionado,
      elevation: 2,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brandTint,
      onDestinationSelected: (index) {
        if (index < directos.length) {
          onSelected(index);
          return;
        }
        _abrirMas(context);
      },
      destinations: [
        for (final section in directos)
          NavigationDestination(
            icon: Icon(section.icon, color: AppColors.textSecondary),
            selectedIcon: Icon(section.icon, color: AppColors.brand),
            label: section.title,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
          selectedIcon: Icon(Icons.more_horiz, color: AppColors.brand),
          label: enMas ? 'Más' : 'Cuenta',
        ),
      ],
    );
  }

  Future<void> _abrirMas(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (hoja) {
        final restantes = <MapEntry<int, BeautySection>>[
          for (var i = _visibles; i < sections.length; i++)
            MapEntry(i, sections[i]),
        ];

        final groupedRestantes = <BeautyCategory, List<MapEntry<int, BeautySection>>>{};
        for (final entry in restantes) {
          groupedRestantes
              .putIfAbsent(entry.value.category, () => [])
              .add(entry);
        }

        final alto = MediaQuery.of(hoja).size.height;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: alto * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groupedRestantes.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        group.key.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.1,
                      children: [
                        for (final entrada in group.value)
                          _AccesoMas(
                            icon: entrada.value.icon,
                            label: entrada.value.title,
                            activo: entrada.key == currentIndex,
                            onTap: () {
                              Navigator.of(hoja).pop();
                              onSelected(entrada.key);
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Seguridad de tu cuenta'),
                    onTap: () {
                      Navigator.of(hoja).pop();
                      showDialog(
                        context: context,
                        builder: (_) => const SecuritySettingsDialog(),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.logout_outlined,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () {
                      Navigator.of(hoja).pop();
                      onSignOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccesoMas extends StatelessWidget {
  const _AccesoMas({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        decoration: BoxDecoration(
          color: activo ? AppColors.brandTint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: activo ? AppColors.brand : AppColors.border,
            width: activo ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: activo ? AppColors.brand : AppColors.textStrong,
              size: 22,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? AppColors.brandDeep : AppColors.textStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
