import 'package:flutter/material.dart';

import '../models/sales_report_summary.dart';
import '../services/sales_report_service.dart';
import '../widgets/app_widgets.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final SalesReportService salesReportService = const SalesReportService();
  late final Future<List<SalesReportSummary>> salesReportFuture;

  @override
  void initState() {
    super.initState();
    salesReportFuture = salesReportService.getSalesReportSummary();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reportes',
      subtitle: 'Resumen de ventas por servicio y estilista.',
      children: [
        const InfoPanel(
          icon: Icons.bar_chart_outlined,
          title: 'Reporte de ventas conectado con Supabase',
          description:
              'Este m\u00f3dulo consulta ventas agrupadas por servicio y estilista mediante una funci\u00f3n segura.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SalesReportSummary>>(
          future: salesReportFuture,
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
                      Text('Cargando reportes desde Supabase...'),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudo cargar el reporte',
                description: snapshot.error.toString(),
              );
            }

            final reports = snapshot.data ?? [];

            if (reports.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin ventas disponibles',
                description:
                    'No hay ventas confirmadas, en proceso o finalizadas para reportar.',
              );
            }

            final totalSales = reports.fold<num>(
              0,
              (sum, report) => sum + report.totalSales,
            );

            final totalTickets = reports.fold<int>(
              0,
              (sum, report) => sum + report.ticketsCount,
            );

            return Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      icon: Icons.attach_money_outlined,
                      title: 'Ventas reportadas',
                      value: _formatMoney(totalSales),
                      description: 'Total vendido seg\u00fan tickets reportables.',
                    ),
                    MetricCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Tickets reportados',
                      value: totalTickets.toString(),
                      description: 'Tickets incluidos en el reporte.',
                    ),
                    MetricCard(
                      icon: Icons.design_services_outlined,
                      title: 'L\u00edneas de reporte',
                      value: reports.length.toString(),
                      description: 'Agrupaciones por servicio y estilista.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Ventas por servicio y estilista'),
                        const SizedBox(height: 14),
                        ...reports.map(
                          (report) => SalesReportCard(report: report),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatMoney(num value) {
    final text = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final positionFromEnd = text.length - i;

      buffer.write(text[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}

class SalesReportCard extends StatelessWidget {
  final SalesReportSummary report;

  const SalesReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 30,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.serviceName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estilista: ${report.stylistName}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${report.ticketsCount} ticket(s) \u00b7 ${report.totalDurationMinutes} min',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            report.formattedTotalSales,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}
