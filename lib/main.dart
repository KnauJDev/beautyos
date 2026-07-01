import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/dashboard_metrics.dart';
import 'models/beauty_service.dart';
import 'services/dashboard_service.dart';
import 'services/services_service.dart';
import 'widgets/app_widgets.dart';

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
      home: const BeautyOSHome(),
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

  final List<BeautySection> sections = const [
    BeautySection('Dashboard', Icons.dashboard_outlined),
    BeautySection('Agenda', Icons.calendar_month_outlined),
    BeautySection('Servicios', Icons.content_cut_outlined),
    BeautySection('Clientes', Icons.people_outline),
    BeautySection('Tickets', Icons.confirmation_number_outlined),
  ];

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    sections[selectedIndex].title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  extended: true,
                  minExtendedWidth: 190,
                  backgroundColor: Colors.white,
                  selectedIconTheme: const IconThemeData(
                    color: Color(0xFF7C3AED),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF2D1B69),
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: Color(0xFF6B7280),
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF6B7280),
                  ),
                  onDestinationSelected: (index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  destinations: sections
                      .map(
                        (section) => NavigationRailDestination(
                          icon: Icon(section.icon),
                          label: Text(section.title),
                        ),
                      )
                      .toList(),
                ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: const [
                    DashboardPage(),
                    AgendaPage(),
                    ServiciosPage(),
                    ClientesPage(),
                    TicketsPage(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
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
  }
}

class BeautySection {
  final String title;
  final IconData icon;

  const BeautySection(this.title, this.icon);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService dashboardService = const DashboardService();
  late final Future<DashboardMetrics> dashboardMetricsFuture;

  @override
  void initState() {
    super.initState();
    dashboardMetricsFuture = dashboardService.getMetrics();
  }


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dashboard',
      subtitle: 'Resumen general del centro de estética.',
      children: [
        FutureBuilder<DashboardMetrics>(
          future: dashboardMetricsFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;
            final metrics = snapshot.data;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  icon: Icons.today_outlined,
                  title: 'Citas de hoy',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.todayTicketsCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Citas programadas para hoy.',
                ),
                MetricCard(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Tickets confirmados',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.confirmedTicketsCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Tickets confirmados en Supabase.',
                ),
                MetricCard(
                  icon: Icons.people_alt_outlined,
                  title: 'Clientes',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.clientsCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Clientes registrados activos.',
                ),
                MetricCard(
                  icon: Icons.spa_outlined,
                  title: 'Servicios activos',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.activeServicesCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Servicios activos visibles.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Actividad reciente'),
        const InfoPanel(
          icon: Icons.analytics_outlined,
          title: 'Dashboard leyendo función segura',
          description:
              'Las métricas principales ahora vienen desde la función get_dashboard_metrics de Supabase, sin exponer tablas privadas completas.',
        ),
      ],
    );
  }
}


class AgendaPage extends StatelessWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Agenda',
      subtitle: 'Aquí veremos las citas por fecha, cliente y estilista.',
      children: const [
        InfoPanel(
          icon: Icons.calendar_month_outlined,
          title: 'Próximo objetivo',
          description:
              'Mostrar las citas creadas en Supabase y organizarlas por día. La agenda nacerá desde los tickets confirmados.',
        ),
        SizedBox(height: 16),
        DemoListCard(
          title: 'Cita demo',
          lines: [
            'Cliente: María Rodríguez',
            'Servicio: Corte de cabello',
            'Estilista: Sandra Gómez',
            'Estado: Confirmado',
          ],
        ),
      ],
    );
  }
}

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key});

  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  final ServicesService servicesService = const ServicesService();
  late final Future<List<BeautyService>> servicesFuture;

  @override
  void initState() {
    super.initState();
    servicesFuture = servicesService.getActiveVisibleServices();
  }


  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Servicios',
      subtitle: 'Catálogo de servicios leído desde Supabase.',
      children: [
        const InfoPanel(
          icon: Icons.cloud_done_outlined,
          title: 'Conexión activa con Supabase',
          description:
              'Este módulo ya consulta la tabla services y muestra los servicios activos y visibles para el cliente.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<BeautyService>>(
          future: servicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Cargando servicios desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los servicios',
                description: snapshot.error.toString(),
              );
            }

            final services = snapshot.data ?? [];

            if (services.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin servicios disponibles',
                description:
                    'No hay servicios activos y visibles para mostrar en este momento.',
              );
            }

            return Card(
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Servicios desde Supabase'),
                    const SizedBox(height: 14),
                    ...services.map((service) => ServiceRow(service: service)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}


class ServiceRow extends StatelessWidget {
  final BeautyService service;

  const ServiceRow({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 22,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${service.category} · ${service.durationMinutes} min · ${service.formattedPrice}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClientesPage extends StatelessWidget {
  const ClientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Clientes',
      subtitle: 'Historial, contacto y preferencias de cada cliente.',
      children: const [
        DemoListCard(
          title: 'Clientes demo',
          lines: [
            'María Rodríguez · +57 310 444 1111',
            'Laura Martínez · +57 310 444 2222',
          ],
        ),
        SizedBox(height: 16),
        InfoPanel(
          icon: Icons.people_outline,
          title: 'Visión comercial',
          description:
              'Este módulo ayudará al negocio a no perder clientes y recordar su historial de servicios.',
        ),
      ],
    );
  }
}

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tickets',
      subtitle:
          'Seguimiento de cada solicitud desde WhatsApp hasta finalización.',
      children: const [
        DemoListCard(
          title: 'Ticket demo',
          lines: [
            'Canal: Manual',
            'Cliente: María Rodríguez',
            'Servicio: Corte de cabello',
            'Estado: Confirmado',
          ],
        ),
        SizedBox(height: 16),
        InfoPanel(
          icon: Icons.confirmation_number_outlined,
          title: 'Corazón operativo de BeautyOS',
          description:
              'El ticket será la pieza central: de aquí saldrá la agenda, el historial, el estado del servicio y los reportes.',
        ),
      ],
    );
  }
}

