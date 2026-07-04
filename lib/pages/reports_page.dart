import 'package:flutter/material.dart';

import '../models/financial_summary.dart';
import '../models/sales_report_summary.dart';
import '../services/financial_summary_service.dart';
import '../services/sales_report_service.dart';
import '../widgets/app_widgets.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final SalesReportService salesReportService = const SalesReportService();
  final FinancialSummaryService financialSummaryService =
      const FinancialSummaryService();

  late final Future<_ReportsPageData> reportsFuture;

  @override
  void initState() {
    super.initState();
    reportsFuture = _loadReportsData();
  }

  Future<_ReportsPageData> _loadReportsData() async {
    final salesReports = await salesReportService.getSalesReportSummary();
    final financialSummary =
        await financialSummaryService.getFinancialSummary();

    return _ReportsPageData(
      salesReports: salesReports,
      financialSummary: financialSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reportes',
      subtitle: 'Resumen financiero, ventas y resultado del negocio.',
      children: [
        const InfoPanel(
          icon: Icons.bar_chart_outlined,
          title: 'Reportes conectados con Supabase',
          description:
              'Este modulo consulta ventas y resultado financiero mediante funciones seguras.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<_ReportsPageData>(
          future: reportsFuture,
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

            final data = snapshot.data!;

            return _ReportsContent(data: data);
          },
        ),
      ],
    );
  }
}

class _ReportsContent extends StatelessWidget {
  final _ReportsPageData data;

  const _ReportsContent({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final reports = data.salesReports;
    final financialSummary = data.financialSummary;

    final totalTickets = reports.fold<int>(
      0,
      (sum, report) => sum + report.ticketsCount,
    );

    return Column(
      children: [
        _FinancialSummarySection(summary: financialSummary),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              icon: Icons.attach_money_outlined,
              title: 'Ventas reportadas',
              value: _formatMoney(financialSummary.totalSales),
              description: 'Total vendido segun tickets reportables.',
            ),
            MetricCard(
              icon: Icons.receipt_long_outlined,
              title: 'Tickets reportados',
              value: totalTickets.toString(),
              description: 'Tickets incluidos en el reporte.',
            ),
            MetricCard(
              icon: Icons.design_services_outlined,
              title: 'Lineas de reporte',
              value: reports.length.toString(),
              description: 'Agrupaciones por servicio y estilista.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SalesReportsSection(reports: reports),
      ],
    );
  }
}

class _FinancialSummarySection extends StatelessWidget {
  final FinancialSummary summary;

  const _FinancialSummarySection({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = summary.netResult >= 0;

    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Resumen financiero'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Ventas',
                  value: _formatMoney(summary.totalSales),
                  description: 'Ingresos por tickets reportables.',
                ),
                MetricCard(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Compras',
                  value: _formatMoney(summary.totalPurchases),
                  description: 'Compras registradas del negocio.',
                ),
                MetricCard(
                  icon: Icons.payments_outlined,
                  title: 'Gastos',
                  value: _formatMoney(summary.totalExpenses),
                  description: 'Gastos operativos registrados.',
                ),
                MetricCard(
                  icon: isProfit
                      ? Icons.trending_up_outlined
                      : Icons.trending_down_outlined,
                  title: 'Resultado neto',
                  value: _formatMoney(summary.netResult),
                  description: summary.netResultText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesReportsSection extends StatelessWidget {
  final List<SalesReportSummary> reports;

  const _SalesReportsSection({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin ventas disponibles',
        description:
            'No hay ventas confirmadas, en proceso o finalizadas para reportar.',
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
            const SectionTitle('Ventas por servicio y estilista'),
            const SizedBox(height: 14),
            ...reports.map(
              (report) => SalesReportCard(report: report),
            ),
          ],
        ),
      ),
    );
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
                  '${report.ticketsCount} ticket(s) · ${report.totalDurationMinutes} min',
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

class _ReportsPageData {
  final List<SalesReportSummary> salesReports;
  final FinancialSummary financialSummary;

  const _ReportsPageData({
    required this.salesReports,
    required this.financialSummary,
  });
}

String _formatMoney(num value) {
  final isNegative = value < 0;
  final text = value.abs().toInt().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    final positionFromEnd = text.length - i;

    buffer.write(text[i]);

    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${isNegative ? '-' : ''}\$$buffer';
}
