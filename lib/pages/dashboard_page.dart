import 'package:flutter/material.dart';

import '../models/dashboard_metrics.dart';
import '../services/dashboard_service.dart';
import '../widgets/app_widgets.dart';

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
      subtitle: 'Resumen general del centro de est\u00e9tica.',
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
          title: 'Dashboard leyendo funci\u00f3n segura',
          description:
              'Las m\u00e9tricas principales ahora vienen desde la funci\u00f3n get_dashboard_metrics de Supabase, sin exponer tablas privadas completas.',
        ),
      ],
    );
  }
}
