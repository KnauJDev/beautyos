import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/dashboard_metrics.dart';

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
  late final Future<DashboardMetrics> dashboardMetricsFuture;

  @override
  void initState() {
    super.initState();
    dashboardMetricsFuture = _loadDashboardMetrics();
  }

  Future<DashboardMetrics> _loadDashboardMetrics() async {
    final response = await Supabase.instance.client
        .rpc('get_dashboard_metrics')
        .single();

    return DashboardMetrics.fromMap(Map<String, dynamic>.from(response));
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
  late final Future<List<BeautyService>> servicesFuture;

  @override
  void initState() {
    super.initState();
    servicesFuture = _loadServices();
  }

  Future<List<BeautyService>> _loadServices() async {
    final response = await Supabase.instance.client
        .from('services')
        .select('id, name, category, duration_minutes, price')
        .eq('active', true)
        .eq('visible_to_customer', true)
        .order('name');

    return response
        .map<BeautyService>((item) => BeautyService.fromMap(item))
        .toList();
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

class BeautyService {
  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final num price;

  const BeautyService({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
  });

  factory BeautyService.fromMap(Map<String, dynamic> map) {
    return BeautyService(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Sin nombre',
      category: map['category']?.toString() ?? 'Sin categoría',
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      price: map['price'] as num? ?? 0,
    );
  }

  String get formattedPrice {
    final value = price.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final positionFromEnd = value.length - i;

      buffer.write(value[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
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

class AppPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 17, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 28),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: const Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D1B69),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D1B69),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF4B5563),
                    ),
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

class DemoListCard extends StatelessWidget {
  final String title;
  final List<String> lines;

  const DemoListCard({super.key, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title),
            const SizedBox(height: 14),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


