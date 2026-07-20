import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_profile.dart';
import 'models/branch_context.dart';
import 'services/branch_context_service.dart';
import 'services/my_profile_service.dart';

import 'pages/auth_gate.dart';
import 'pages/agenda_page.dart';
import 'pages/clients_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/my_stylist_agenda_page.dart';
import 'pages/my_stylist_work_photos_page.dart';
import 'pages/work_photos_page.dart';
import 'widgets/session_badge.dart';
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
    return MaterialApp(
      title: 'BeautyOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F5FF),
      ),
      home: const AuthGate(authenticatedChild: BeautyOSHome()),
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

  late final Future<_HomeContextData> homeContextFuture;
  BranchContext? selectedBranch;

  @override
  void initState() {
    super.initState();
    homeContextFuture = _loadHomeContext();
  }

  Future<_HomeContextData> _loadHomeContext() async {
    final profile = await myProfileService.getMyProfile();

    if (profile == null) {
      return const _HomeContextData(profile: null, branches: []);
    }

    final branches = await branchContextService.getAccessibleBranches(
      profile: profile,
    );
    return _HomeContextData(profile: profile, branches: branches);
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  List<BeautyModule> _modulesForProfile(
    MyProfile? profile,
    BranchContext branch,
  ) {
    final role = profile?.role ?? 'client';

    final modules = <BeautyModule>[
      const BeautyModule(
        section: BeautySection('Dashboard', Icons.dashboard_outlined),
        page: DashboardPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Mi agenda',
          Icons.event_available_outlined,
        ),
        page: MyStylistAgendaPage(
          key: ValueKey('my-agenda-${branch.branchId ?? 'legacy'}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'stylist'},
      ),
      const BeautyModule(
        section: BeautySection('Mis fotos', Icons.photo_library_outlined),
        page: MyStylistWorkPhotosPage(),
        allowedRoles: <String>{'stylist'},
      ),
      BeautyModule(
        section: const BeautySection('Agenda', Icons.calendar_month_outlined),
        page: AgendaPage(
          key: ValueKey('agenda-${branch.branchId ?? 'legacy'}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Servicios', Icons.content_cut_outlined),
        page: ServiciosPage(),
        allowedRoles: <String>{
          'owner',
          'admin',
          'stylist',
          'assistant',
          'client',
        },
      ),
      const BeautyModule(
        section: BeautySection('Estilistas', Icons.badge_outlined),
        page: EstilistasPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Usuarios', Icons.manage_accounts_outlined),
        page: UsuariosPage(),
        allowedRoles: <String>{'owner'},
      ),
      const BeautyModule(
        section: BeautySection('Clientes', Icons.people_outline),
        page: ClientesPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      BeautyModule(
        section: const BeautySection(
          'Tickets',
          Icons.confirmation_number_outlined,
        ),
        page: TicketsPage(
          key: ValueKey('tickets-${branch.branchId ?? 'legacy'}'),
          branchId: branch.branchId,
        ),
        allowedRoles: const <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Reportes', Icons.bar_chart_outlined),
        page: ReportesPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Compras', Icons.shopping_cart_outlined),
        page: ComprasPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Gastos', Icons.payments_outlined),
        page: GastosPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection(
          'Fotos de trabajos',
          Icons.photo_library_outlined,
        ),
        page: FotosTrabajosPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Rese\u00f1as', Icons.rate_review_outlined),
        page: ResenasPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Inventario', Icons.inventory_2_outlined),
        page: InventarioPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Configuraci\u00f3n', Icons.settings_outlined),
        page: ConfiguracionPage(),
        allowedRoles: <String>{'owner', 'admin'},
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
              title: const Text('BeautyOS'),
              backgroundColor: const Color(0xFF7C3AED),
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

        if (profile == null || branches.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('BeautyOS'),
              backgroundColor: const Color(0xFF7C3AED),
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
                'BeautyOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF7C3AED),
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
                title: const Text(
                  'BeautyOS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                actions: [
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
                  const SizedBox(width: 12),
                  const SessionBadge(),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar sesi\u00f3n',
                    onPressed: signOut,
                    icon: const Icon(Icons.logout_outlined),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Row(
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
                    child: IndexedStack(index: currentIndex, children: pages),
                  ),
                ],
              ),
              bottomNavigationBar: isWide
                  ? null
                  : NavigationBar(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      destinations: sections
                          .map(
                            (section) => NavigationDestination(
                              icon: Icon(section.icon),
                              label: section.title,
                            ),
                          )
                          .toList(),
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
                    color: const Color(0xFF7C3AED),
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

class _HomeContextData {
  const _HomeContextData({required this.profile, required this.branches});

  final MyProfile? profile;
  final List<BranchContext> branches;
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
                    ? const Color(0xFFEEE6FF)
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
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF6B7280),
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
                                  ? const Color(0xFF2D1B69)
                                  : const Color(0xFF6B7280),
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
