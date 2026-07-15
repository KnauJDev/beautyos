import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/my_profile.dart';
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

  late final Future<MyProfile?> profileFuture;

  @override
  void initState() {
    super.initState();
    profileFuture = myProfileService.getMyProfile();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  List<BeautyModule> _modulesForProfile(MyProfile? profile) {
    final role = profile?.role ?? 'client';

    final modules = <BeautyModule>[
      const BeautyModule(
        section: BeautySection('Dashboard', Icons.dashboard_outlined),
        page: DashboardPage(),
        allowedRoles: <String>{'owner', 'admin'},
      ),
      const BeautyModule(
        section: BeautySection('Mi agenda', Icons.event_available_outlined),
        page: MyStylistAgendaPage(),
        allowedRoles: <String>{'stylist'},
      ),
      const BeautyModule(
        section: BeautySection('Mis fotos', Icons.photo_library_outlined),
        page: MyStylistWorkPhotosPage(),
        allowedRoles: <String>{'stylist'},
      ),
      const BeautyModule(
        section: BeautySection('Agenda', Icons.calendar_month_outlined),
        page: AgendaPage(),
        allowedRoles: <String>{'owner', 'admin'},
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
      const BeautyModule(
        section: BeautySection('Tickets', Icons.confirmation_number_outlined),
        page: TicketsPage(),
        allowedRoles: <String>{'owner', 'admin'},
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
    return FutureBuilder<MyProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final modules = _modulesForProfile(snapshot.data);

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
