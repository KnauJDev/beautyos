import 'package:flutter/material.dart';

import '../models/financial_summary.dart';
import '../models/commission_summary.dart';
import '../models/daily_close_summary.dart';
import '../models/sales_report_summary.dart';
import '../services/daily_close_service.dart';
import '../services/financial_summary_service.dart';
import '../services/sales_report_service.dart';
import '../widgets/app_widgets.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key, required this.branchId});

  final String? branchId;

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  late final SalesReportService salesReportService;
  late final FinancialSummaryService financialSummaryService;
  late final DailyCloseService dailyCloseService;

  late Future<_ReportsPageData> reportsFuture;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    salesReportService = SalesReportService(branchId: widget.branchId);
    financialSummaryService = FinancialSummaryService(
      branchId: widget.branchId,
    );
    dailyCloseService = DailyCloseService(branchId: widget.branchId);
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    reportsFuture = _loadReportsData();
  }

  Future<_ReportsPageData> _loadReportsData() async {
    final salesReports = await salesReportService.getSalesReportSummary();
    final financialSummary = await financialSummaryService
        .getFinancialSummary();
    final dailyClose = await dailyCloseService.getDailyClose(selectedDate);
    final commissions = await dailyCloseService.getCommissionSummary(
      selectedDate,
    );

    return _ReportsPageData(
      salesReports: salesReports,
      financialSummary: financialSummary,
      dailyClose: dailyClose,
      commissions: commissions,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
      reportsFuture = _loadReportsData();
    });
  }

  void _refresh() {
    setState(() {
      reportsFuture = _loadReportsData();
    });
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Cierre del ${_formatDate(selectedDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar reportes'),
            ),
          ],
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

  const _ReportsContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final reports = data.salesReports;
    final financialSummary = data.financialSummary;
    final dailyClose = data.dailyClose;

    final totalTickets = reports.fold<int>(
      0,
      (sum, report) => sum + report.ticketsCount,
    );

    return Column(
      children: [
        _DailyCloseSection(summary: dailyClose, commissions: data.commissions),
        const SizedBox(height: 16),
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
              description: 'Dinero efectivamente recibido.',
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

  const _FinancialSummarySection({required this.summary});

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
                  description: 'Pagos registrados y no anulados.',
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
                  icon: Icons.badge_outlined,
                  title: 'Comisiones',
                  value: _formatMoney(summary.totalCommissions),
                  description: 'Comisiones vigentes por servicios cobrados.',
                ),
                MetricCard(
                  icon: isProfit
                      ? Icons.trending_up_outlined
                      : Icons.trending_down_outlined,
                  title: 'Resultado neto',
                  value: _formatMoney(summary.netResult),
                  description:
                      '${summary.netResultText} despues de comisiones.',
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

  const _SalesReportsSection({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin ventas disponibles',
        description: 'No hay tickets cerrados y pagados para reportar.',
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
            ...reports.map((report) => SalesReportCard(report: report)),
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
  final DailyCloseSummary dailyClose;
  final List<CommissionSummary> commissions;

  const _ReportsPageData({
    required this.salesReports,
    required this.financialSummary,
    required this.dailyClose,
    required this.commissions,
  });
}

class _DailyCloseSection extends StatelessWidget {
  final DailyCloseSummary summary;
  final List<CommissionSummary> commissions;

  const _DailyCloseSection({required this.summary, required this.commissions});

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.estimatedResult >= 0;

    return Card(
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Cierre diario · ${_formatDate(summary.businessDate)}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Resume el dinero recibido y las obligaciones generadas durante el día.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Ingresos del día',
                  value: _formatMoney(summary.totalReceived),
                  description:
                      '${summary.paymentsCount} pago(s) en ${summary.paidTicketsCount} ticket(s).',
                ),
                MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Efectivo esperado',
                  value: _formatMoney(summary.expectedCash),
                  description: 'Efectivo recibido menos salidas en efectivo.',
                ),
                MetricCard(
                  icon: Icons.badge_outlined,
                  title: 'Comisiones del día',
                  value: _formatMoney(summary.totalCommissions),
                  description:
                      '${summary.commissionServicesCount} servicio(s) liquidado(s).',
                ),
                MetricCard(
                  icon: isPositive
                      ? Icons.trending_up_outlined
                      : Icons.trending_down_outlined,
                  title: 'Resultado estimado',
                  value: _formatMoney(summary.estimatedResult),
                  description: 'Ingresos menos compras, gastos y comisiones.',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('Medios de pago y salidas'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _AmountLine(label: 'Efectivo', value: summary.cashReceived),
                _AmountLine(label: 'Tarjeta', value: summary.cardReceived),
                _AmountLine(
                  label: 'Transferencia',
                  value: summary.transferReceived,
                ),
                _AmountLine(label: 'Otros', value: summary.otherReceived),
                _AmountLine(label: 'Compras', value: summary.totalPurchases),
                _AmountLine(label: 'Gastos', value: summary.totalExpenses),
              ],
            ),
            const SizedBox(height: 20),
            const SectionTitle('Comisiones por estilista'),
            const SizedBox(height: 12),
            if (commissions.isEmpty)
              const Text(
                'No se generaron comisiones en esta fecha.',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              ...commissions.map(
                (commission) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commission.stylistName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D1B69),
                              ),
                            ),
                            Text(
                              '${commission.servicesCount} servicio(s) · Ventas ${_formatMoney(commission.serviceSales)}',
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatMoney(commission.commissionTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
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

class _AmountLine extends StatelessWidget {
  final String label;
  final double value;

  const _AmountLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          Text(
            _formatMoney(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
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
