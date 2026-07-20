import 'package:flutter/material.dart';

import '../models/dashboard_metrics.dart';
import '../services/dashboard_service.dart';
import '../widgets/app_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardService dashboardService;
  late final Future<DashboardMetrics> dashboardMetricsFuture;

  @override
  void initState() {
    super.initState();
    dashboardService = DashboardService(branchId: widget.branchId);
    dashboardMetricsFuture = dashboardService.getMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dashboard',
      subtitle: 'Resumen operativo de la sede seleccionada.',
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
                  title: 'Clientes del negocio',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.clientsCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Catálogo activo de todo el negocio.',
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
                MetricCard(
                  icon: Icons.badge_outlined,
                  title: 'Estilistas activos',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.activeStylistsCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Equipo activo disponible.',
                ),
                MetricCard(
                  icon: Icons.assignment_ind_outlined,
                  title: 'Servicios asignados',
                  value: hasError
                      ? 'Error'
                      : isLoading
                      ? '...'
                      : metrics!.activeStylistServicesCount.toString(),
                  description: hasError
                      ? 'No se pudo consultar Supabase.'
                      : 'Relaciones activas estilista-servicio.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Actividad reciente'),
        const InfoPanel(
          icon: Icons.analytics_outlined,
          title: 'Dashboard autorizado por sede',
          description:
              'Las métricas operativas corresponden a la sede seleccionada; clientes conserva alcance de catálogo del negocio.',
        ),
      ],
    );
  }
}
