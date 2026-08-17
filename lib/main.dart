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
import 'pages/agenda_page.dart';
import 'pages/clients_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/my_commission_summary_page.dart';
import 'pages/my_stylist_agenda_page.dart';
import 'pages/my_stylist_reviews_page.dart';
import 'pages/my_stylist_work_photos_page.dart';
import 'pages/work_photos_page.dart';
import 'widgets/create_branch_dialog.dart';
import 'widgets/security_settings_dialog.dart';
import 'theme/app_theme.dart';
import 'widgets/session_badge.dart';
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

    // Un solo sitio decide el aspecto de toda la aplicacion (D-102). El tema
    // del negocio no se conoce al arrancar -- llega con los datos de la sede o
    // de la reserva publica --, asi que `MaterialApp` se reconstruye cuando
    // `AppBrand.aplicar()` cambia la paleta (D-109).
    return ValueListenableBuilder<BrandPalette>(
      valueListenable: AppBrand.activo,
      builder: (context, palette, _) {
        // `home` se construye **dentro** del builder a proposito. Las
        // pantallas leen `AppColors` directamente y no `Theme.of(context)`,
        // asi que necesitan volver a dibujarse de verdad; si el widget fuera
        // siempre la misma instancia, Flutter se saltaria ese subarbol al ver
        // que no cambio y el tema nuevo solo entraria a medias. Al ser
        // widgets sin `key`, su estado se conserva igual.
        final Widget home;
        if (publicBranchId != null && publicBranchId.trim().isNotEmpty) {
          home = PublicBookingPage(branchId: publicBranchId.trim());
        } else if (publicReviewTicketId != null &&
            publicReviewTicketId.trim().isNotEmpty) {
          home = PublicReviewPage(ticketId: publicReviewTicketId.trim());
        } else if (isPublicPlans) {
          home = const PublicPlansPage();
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

class _BeautyOSHomeState extends State<BeautyOSHome> {
  int selectedIndex = 0;

  final MyProfileService myProfileService = const MyProfileService();
  final BranchContextService branchContextService =
      const BranchContextService();
  final TeamInvitationsService teamInvitationsService =
      const TeamInvitationsService();
  final TenantSubscriptionService tenantSubscriptionService =
      const TenantSubscriptionService();

  late Future<_HomeContextData> homeContextFuture;
  BranchContext? selectedBranch;

  @override
  void initState() {
    super.initState();
    homeContextFuture = _loadHomeContext();
  }

  Future<_HomeContextData> _loadHomeContext() async {
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

    // El tema se aplica aqui y no en `build` porque cambiar la paleta
    // reconstruye `MaterialApp`, y eso no se puede disparar en mitad de un
    // build. Aqui estamos despues de que resolvio la consulta, que es el
    // primer momento en que se sabe de que negocio es quien entro.
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
    // Se vuelve al morado de Salon y Mas: la pantalla de login no es de ningun
    // negocio, y dejarla con los colores del ultimo que entro seria confuso en
    // un mostrador donde el equipo comparte el mismo equipo.
    AppBrand.aplicar(null, null);
    await MonitoreoService.olvidarContexto();
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _openCreateBranchDialog(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateBranchDialog(),
    );

    if (created != true) return;

    setState(() {
      homeContextFuture = _loadHomeContext();
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sede creada. Ya puedes asignarle servicios y estilistas desde '
          'sus propias pantallas.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  List<BeautyModule> _modulesForProfile(
    MyProfile? profile,
    BranchContext branch,
    List<BranchContext> branches,
  ) {
    final role = profile?.role ?? 'client';

    final modules = <BeautyModule>[
      BeautyModule(
        section: const BeautySection('Dashboard', Icons.dashboard_outlined),
        page: DashboardPage(
          // El Dashboard es el unico modulo que puede mirar varias sedes a la
          // vez (D-110): "como va mi negocio" para quien tiene dos locales son
          // los dos juntos. Por eso recibe la lista y no solo la sede activa.
          key: const ValueKey('dashboard'),
          branchId: branch.branchId,
          branches: branches,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mi agenda',
          Icons.event_available_outlined,
        ),
        page: MyStylistAgendaPage(
          key: ValueKey('my-agenda-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection('Mis fotos', Icons.photo_library_outlined),
        page: MyStylistWorkPhotosPage(
          key: ValueKey('my-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection('Mis reseñas', Icons.star_outline),
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
        ),
        page: MyCommissionSummaryPage(
          key: ValueKey('my-commissions-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection('Agenda', Icons.calendar_month_outlined),
        page: AgendaPage(
          key: ValueKey('agenda-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        // El asistente es el rol de recepcion y caja: el backend ya lo autoriza
        // a agendar, reprogramar, cobrar y crear clientes (D-092), asi que ve
        // Agenda, Tickets y Clientes. Nada mas.
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      BeautyModule(
        section: const BeautySection('Servicios', Icons.content_cut_outlined),
        page: ServiciosPage(
          key: ValueKey('services-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection('Estilistas', Icons.badge_outlined),
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
        ),
        page: UsuariosPage(
          key: ValueKey('users-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Clientes', Icons.people_outline),
        page: ClientesPage(),
        allowedRoles: <String>{'owner', 'admin', 'assistant'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Tickets',
          Icons.confirmation_number_outlined,
        ),
        page: TicketsPage(
          key: ValueKey('tickets-${branch.branchId}'),
          branchId: branch.branchId,
          isOwnerOrAdmin: role == 'owner' || role == 'admin',
        ),
        allowedRoles: const <String>{'owner', 'admin', 'assistant'},
      ),
      BeautyModule(
        section: const BeautySection('Reportes', Icons.bar_chart_outlined),
        page: ReportesPage(
          key: ValueKey('reports-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection('Compras', Icons.shopping_cart_outlined),
        page: ComprasPage(
          key: ValueKey('purchases-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection('Gastos', Icons.payments_outlined),
        page: GastosPage(
          key: ValueKey('expenses-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Fotos de trabajos',
          Icons.photo_library_outlined,
        ),
        page: FotosTrabajosPage(
          key: ValueKey('work-photos-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Rese\u00f1as',
          Icons.rate_review_outlined,
        ),
        page: ResenasPage(
          key: ValueKey('reviews-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection('Inventario', Icons.inventory_2_outlined),
        page: InventarioPage(
          key: ValueKey('inventory-${branch.branchId}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Configuraci\u00f3n',
          Icons.settings_outlined,
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
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Salón y Más'),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
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
            appBar: AppBar(
              title: const Text('Salón y Más'),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
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
            appBar: AppBar(
              title: const Text(
                'Salón y Más',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesi\u00f3n',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
            body: const Center(
              child: Text('Tu usuario no tiene modulos asignados.'),
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
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (branch.tenantLogoUrl != null) ...[
                      // Sobre fondo blanco y algo mas grande (D-106): a 28 px
                      // y directamente sobre el morado, un logo con detalle se
                      // veia como una mancha clara sin forma.
                      Container(
                        width: 34,
                        height: 34,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            branch.tenantLogoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // En celular la marca cede su sitio al modulo actual: el
                    // nombre del producto no le dice nada a quien ya esta
                    // dentro, y era parte de por que la barra no cabia (D-105).
                    if (isWide)
                      const Text(
                        'Salón y Más',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )
                    else ...[
                      Flexible(
                        child: _DosLineas(
                          arriba: sections[currentIndex].title,
                          // Con varias sedes se muestra **la sede**, no el
                          // negocio (D-108): si no, cambiar de sede no cambia
                          // nada en pantalla y se puede acabar cobrando en la
                          // sede equivocada sin notarlo. Con una sola sede el
                          // nombre del negocio informa mas.
                          abajo: branches.length > 1
                              ? branch.branchName
                              : branch.tenantName,
                        ),
                      ),
                      // Quien esta trabajando tiene que verse sin abrir nada
                      // (D-106): al compactar la barra se quito la identidad y
                      // no quedaba forma de saber con que cuenta se opera --
                      // critico en un mostrador donde el equipo comparte
                      // equipo.
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: _DosLineas(
                          arriba: profile.fullName,
                          abajo: profile.roleText,
                          alineacion: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                actions: [
                  if (isWide) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Text(
                          sections[currentIndex].title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // En celular con una sola sede este icono no hace nada: es
                  // decorativo y encima parece que se puede tocar (D-106). El
                  // nombre del negocio ya se lee bajo el modulo, asi que
                  // estorba. Con varias sedes si es el selector y se queda.
                  if (isWide || branches.length > 1)
                    _BranchSelector(
                      branches: branches,
                      selectedBranch: branch,
                      compact: !isWide,
                      onSelected: (value) {
                        if (value.branchId == branch.branchId) {
                          return;
                        }

                        // Cambiar de sede puede cambiar de negocio, y cada
                        // negocio tiene su tema. Con una sola empresa esto no
                        // hace nada.
                        AppBrand.aplicar(
                          value.tenantThemeKey,
                          value.tenantBrandColor,
                        );

                        setState(() {
                          selectedBranch = value;
                        });
                      },
                    ),
                  if (profile.role == 'owner')
                    IconButton(
                      tooltip: 'Agregar sede',
                      onPressed: () => _openCreateBranchDialog(context),
                      icon: const Icon(Icons.add_business_outlined),
                    ),
                  // En celular, quien eres, tu seguridad y salir se mudan al
                  // menu "Mas" (D-105). Arriba solo queda lo que se usa
                  // mientras se trabaja: el modulo y la sede.
                  if (isWide) ...[
                    const SizedBox(width: 12),
                    const SessionBadge(),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Seguridad de tu cuenta',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const SecuritySettingsDialog(),
                      ),
                      icon: const Icon(Icons.security_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Cerrar sesi\u00f3n',
                      onPressed: signOut,
                      icon: const Icon(Icons.logout_outlined),
                    ),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  // Va arriba del todo y lo ve cualquier rol: una version vieja
                  // le afecta igual a la recepcionista que al dueno (D-099).
                  const UpdateBanner(),
                  if (profile.role == 'owner' || profile.role == 'admin')
                    const _TrialBanner(),
                  Expanded(
                    child: Row(
                      children: [
                        if (isWide)
                          _SideMenu(
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

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
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
    if (branches.length == 1) {
      return Tooltip(
        message: selectedBranch.branchName,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 20),
            if (!compact) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  selectedBranch.branchName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return PopupMenuButton<BranchContext>(
      tooltip: 'Cambiar sede',
      initialValue: selectedBranch,
      onSelected: onSelected,
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
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      branch.branchName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 20),
          if (!compact) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                selectedBranch.branchName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _TrialBanner extends StatefulWidget {
  const _TrialBanner();

  @override
  State<_TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends State<_TrialBanner> {
  final subscriptionService = const TenantSubscriptionService();
  final epaycoService = const EpaycoCheckoutService();
  late Future<TenantSubscriptionStatus?> subscriptionFuture;

  @override
  void initState() {
    super.initState();
    _recargarSuscripcion();
  }

  void _recargarSuscripcion() {
    setState(() {
      subscriptionFuture = subscriptionService.getMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantSubscriptionStatus?>(
      future: subscriptionFuture,
      builder: (context, snapshot) {
        final subscription = snapshot.data;

        if (subscription == null) {
          return const SizedBox.shrink();
        }

        // 1. CASO PERIODO DE GRACIA (D-141: Días 1 al 5)
        if (subscription.isGrace) {
          final graceDays = subscription.graceDaysRemaining ?? 5;
          final isUrgent = graceDays <= 2;
          final backgroundColor = isUrgent ? AppColors.dangerTint : AppColors.warningTint;
          final foregroundColor = isUrgent ? AppColors.danger : AppColors.warning;

          final message =
              'Tienes $graceDays ${graceDays == 1 ? "día" : "días"} de gracia para realizar tu pago y continuar disfrutando de tus servicios sin interrupción.';

          return _buildBannerContainer(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            icon: Icons.warning_amber_rounded,
            message: message,
            actionLabel: 'Pagar ahora',
            onAction: () => epaycoService.iniciarPago(
              context,
              subscription,
              onPaymentLaunched: _recargarSuscripcion,
            ),
          );
        }

        // 2. CASO SUSPENDIDO O PRUEBA VENCIDA SIN GRACIA
        if (subscription.isSuspended) {
          return _buildBannerContainer(
            backgroundColor: AppColors.dangerTint,
            foregroundColor: AppColors.danger,
            icon: Icons.error_outline,
            message:
                'Tu suscripción está suspendida por falta de pago. No se pueden crear reservas ni citas nuevas hasta reactivar tu plan.',
            actionLabel: 'Reactivar ahora',
            onAction: () => epaycoService.iniciarPago(
              context,
              subscription,
              onPaymentLaunched: _recargarSuscripcion,
            ),
          );
        }

        // 3. CASO PRUEBA GRATIS POR VENCER (<= 10 DÍAS)
        if (subscription.isTrialing) {
          final trialDays = subscription.trialDaysRemaining;
          if (trialDays == null || trialDays > 10) {
            return const SizedBox.shrink();
          }

          final expired = trialDays < 0;
          final urgent = !expired && trialDays <= 3;

          final backgroundColor = expired
              ? AppColors.dangerTint
              : urgent
                  ? AppColors.warningTint
                  : AppColors.warningTint;
          final foregroundColor = expired
              ? AppColors.danger
              : urgent
                  ? AppColors.warning
                  : AppColors.warning;

          final message = expired
              ? 'Tu prueba gratis venció. Activa tu plan para no perder el acceso a la agenda.'
              : trialDays == 0
                  ? 'Tu prueba gratis termina hoy.'
                  : 'Tu prueba gratis termina en $trialDays ${trialDays == 1 ? "día" : "días"}.';

          return _buildBannerContainer(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            icon: expired ? Icons.error_outline : Icons.info_outline,
            message: message,
            actionLabel: expired ? 'Pagar ahora' : 'Activar plan',
            onAction: () => epaycoService.iniciarPago(
              context,
              subscription,
              onPaymentLaunched: _recargarSuscripcion,
            ),
          );
        }

        // 4. CASO SUSCRIPCIÓN ACTIVA POR VENCER (<= 5 DÍAS)
        if (subscription.isActive) {
          final periodDays = subscription.periodDaysRemaining;
          if (periodDays != null && periodDays <= 5 && periodDays >= 0) {
            final urgent = periodDays <= 2;
            final backgroundColor = urgent ? AppColors.warningTint : AppColors.brandSurface;
            final foregroundColor = urgent ? AppColors.warning : AppColors.brand;

            final message = periodDays == 0
                ? 'Tu mensualidad de Salón y Más vence hoy.'
                : 'Tu mensualidad de Salón y Más vence en $periodDays ${periodDays == 1 ? "día" : "días"}.';

            return _buildBannerContainer(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              icon: Icons.calendar_today_outlined,
              message: message,
              actionLabel: 'Renovar mensualidad',
              onAction: () => epaycoService.iniciarPago(
                context,
                subscription,
                onPaymentLaunched: _recargarSuscripcion,
              ),
            );
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBannerContainer({
    required Color backgroundColor,
    required Color foregroundColor,
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: foregroundColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
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

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.sections,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<BeautySection> sections;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: isSelected
                    ? AppColors.brandTint
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onDestinationSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          section.icon,
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            section.title,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.brandDeep
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BeautySection {
  final String title;
  final IconData icon;

  const BeautySection(this.title, this.icon);
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

/// Barra inferior de celular (D-105).
///
/// Antes se metian **los 15 modulos** en el ancho de un telefono y las
/// palabras se partian en pedazos ilegibles: "Das hbo ard", "Foto s de trab
/// ajos". Ahora caben cuatro y el resto vive en "Mas".
///
/// **Todos los roles llevan "Mas", tengan 3 modulos o 14**, por dos motivos:
/// nunca esta vacio -- ahi viven Seguridad y Cerrar sesion, que antes eran
/// iconos apretujados arriba -- y deja sitio para crecer sin rediseniar la
/// barra cada vez que un rol gane una herramienta.
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

  /// Cuatro y no cinco: el quinto puesto siempre es "Mas".
  static const _visibles = 4;

  @override
  Widget build(BuildContext context) {
    final directos = sections.take(_visibles).toList();
    final enMas = sections.length > _visibles;

    // Si el modulo activo vive dentro de "Mas", se resalta "Mas".
    final seleccionado = currentIndex < directos.length
        ? currentIndex
        : directos.length;

    return NavigationBar(
      selectedIndex: seleccionado,
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
            icon: Icon(section.icon),
            label: section.title,
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
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
      // **Sin esto, "Mas" era una trampa en celular** (hallazgo del propietario,
      // 08-ago). Con 14 modulos la rejilla mide mas que la hoja, y como la hoja
      // no se desplazaba, lo de abajo -- Configuracion, Seguridad y **Cerrar
      // sesion** -- quedaba fuera de la pantalla y era imposible de alcanzar.
      // En horizontal ni siquiera cabia la primera fila completa.
      isScrollControlled: true,
      builder: (hoja) {
        final restantes = <MapEntry<int, BeautySection>>[
          for (var i = _visibles; i < sections.length; i++)
            MapEntry(i, sections[i]),
        ];

        final alto = MediaQuery.of(hoja).size.height;
        final apaisado =
            MediaQuery.of(hoja).orientation == Orientation.landscape;

        return SafeArea(
          child: ConstrainedBox(
            // En horizontal se toma casi toda la pantalla: la altura util es
            // tan poca que dejar un margen elegante significaria no ver nada.
            constraints: BoxConstraints(maxHeight: alto * (apaisado ? 0.92 : 0.8)),
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
                  if (restantes.isNotEmpty) ...[
                    GridView.count(
                      // Cuatro columnas en horizontal: hay ancho de sobra y
                      // altura ninguna, asi que conviene gastar lo que sobra.
                      crossAxisCount: apaisado ? 4 : 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.15,
                    children: [
                      for (final entrada in restantes)
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
                    const Divider(),
                  ],
                  // Seguridad y salir viven aqui desde D-105: en la barra de
                  // arriba eran dos iconos que no cabian en un telefono.
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
          color: activo ? AppColors.brandTint : null,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.brand, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloque de dos lineas para la barra superior en celular (D-106).
///
/// Se usa dos veces: modulo con negocio a la izquierda, y persona con rol a la
/// derecha. Ambas lineas recortan con puntos suspensivos, porque un nombre
/// largo no puede empujar el resto de la barra fuera de la pantalla.
class _DosLineas extends StatelessWidget {
  const _DosLineas({
    required this.arriba,
    required this.abajo,
    this.alineacion = CrossAxisAlignment.start,
  });

  final String arriba;
  final String abajo;
  final CrossAxisAlignment alineacion;

  @override
  Widget build(BuildContext context) {
    final alDerecha = alineacion == CrossAxisAlignment.end;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alineacion,
      children: [
        Text(
          arriba,
          overflow: TextOverflow.ellipsis,
          textAlign: alDerecha ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        Text(
          abajo,
          overflow: TextOverflow.ellipsis,
          textAlign: alDerecha ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.brandTint,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
