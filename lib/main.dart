import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_profile.dart';
import 'models/branch_context.dart';
import 'models/pending_invitation.dart';
import 'models/tenant_subscription_status.dart';
import 'services/branch_context_service.dart';
import 'services/my_profile_service.dart';
import 'services/team_invitations_service.dart';
import 'services/tenant_subscription_service.dart';

import 'pages/accept_invitation_page.dart';
import 'pages/auth_gate.dart';
import 'pages/authenticated_router.dart';
import 'pages/complete_tenant_setup_page.dart';
import 'pages/public_booking_page.dart';
import 'pages/public_review_page.dart';
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

  runApp(const BeautyOSApp());
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

    Widget home;
    if (publicBranchId != null && publicBranchId.trim().isNotEmpty) {
      home = PublicBookingPage(branchId: publicBranchId.trim());
    } else if (publicReviewTicketId != null &&
        publicReviewTicketId.trim().isNotEmpty) {
      home = PublicReviewPage(ticketId: publicReviewTicketId.trim());
    } else {
      home = const AuthGate(
        authenticatedChild: AuthenticatedRouter(businessApp: BeautyOSHome()),
      );
    }

    return MaterialApp(
      title: 'Salón y Más',
      debugShowCheckedModeBanner: false,
      // Un solo sitio decide el aspecto de toda la aplicacion (D-102). Cuando
      // llegue la marca blanca, aqui entrara el tema del negocio.
      theme: AppTheme.light(),
      home: home,
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

    final branches = await branchContextService.getAccessibleBranches();
    return _HomeContextData(profile: profile, branches: branches);
  }

  Future<void> signOut() async {
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
  ) {
    final role = profile?.role ?? 'client';

    final modules = <BeautyModule>[
      BeautyModule(
        section: const BeautySection('Dashboard', Icons.dashboard_outlined),
        page: DashboardPage(
          key: ValueKey('dashboard-${branch.branchId}'),
          branchId: branch.branchId,
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
        final modules = _modulesForProfile(profile, branch);

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
  late Future<TenantSubscriptionStatus?> subscriptionFuture;

  @override
  void initState() {
    super.initState();
    subscriptionFuture = subscriptionService.getMySubscription();
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

        final daysRemaining = subscription.trialDaysRemaining;

        if (daysRemaining == null || daysRemaining > 10) {
          return const SizedBox.shrink();
        }

        final expired = daysRemaining < 0;
        final urgent = !expired && daysRemaining <= 3;

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
            ? 'Tu prueba gratis venció. No se pueden crear reservas ni '
                  'citas nuevas hasta reactivar tu plan.'
            : daysRemaining == 0
            ? 'Tu prueba gratis termina hoy.'
            : 'Tu prueba gratis termina en $daysRemaining '
                  '${daysRemaining == 1 ? "día" : "días"}.';

        return Container(
          width: double.infinity,
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                expired ? Icons.error_outline : Icons.info_outline,
                color: foregroundColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeContextData {
  const _HomeContextData({
    required this.profile,
    required this.branches,
    this.pendingInvitation,
  });

  final MyProfile? profile;
  final List<BranchContext> branches;
  final PendingInvitation? pendingInvitation;
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
      builder: (hoja) {
        final restantes = <MapEntry<int, BeautySection>>[
          for (var i = _visibles; i < sections.length; i++)
            MapEntry(i, sections[i]),
        ];

        return SafeArea(
          child: Padding(
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
                    crossAxisCount: 3,
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
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.brandTint,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
