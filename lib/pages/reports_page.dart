import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/branch_context.dart';
import '../models/branch_report_v3.dart';
import '../models/ticket_board.dart' show formatCOP;
import '../services/branch_reports_service.dart';
import '../widgets/app_widgets.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({
    super.key,
    required this.branchId,
    this.branches = const <BranchContext>[],
  });

  final String branchId;

  /// Las sedes que este usuario puede consultar (D-194). Con una sola, el
  /// selector de consolidado ni se dibuja: seria un boton que no hace nada.
  final List<BranchContext> branches;

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  late final BranchReportsService reportsService;
  late Future<BranchReportV3> reportsFuture;

  String selectedPeriod = 'hoy'; // 'hoy', 'semana', 'mes', 'rango'

  /// Mirar el negocio entero en vez de esta sede (D-194).
  bool _consolidado = false;
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    reportsService = BranchReportsService(branchId: widget.branchId);
    _applyPeriod('hoy');
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      selectedPeriod = period;
      switch (period) {
        case 'hoy':
          startDate = today;
          endDate = today;
          break;
        case 'semana':
          // Inicio de la semana (Lunes)
          final monday = today.subtract(Duration(days: today.weekday - 1));
          startDate = monday;
          endDate = today;
          break;
        case 'mes':
          startDate = DateTime(today.year, today.month, 1);
          endDate = today;
          break;
      }
      reportsFuture = _pedirReporte();
    });
  }

  Future<BranchReportV3> _pedirReporte() {
    return _consolidado
        ? reportsService.getTenantReport(startDate: startDate, endDate: endDate)
        : reportsService.getBranchReport(
            startDate: startDate,
            endDate: endDate,
          );
  }

  void _cambiarAmbito(bool consolidado) {
    if (_consolidado == consolidado) return;
    setState(() {
      _consolidado = consolidado;
      reportsFuture = _pedirReporte();
    });
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.brand,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedPeriod = 'rango';
      startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
      endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
      reportsFuture = _pedirReporte();
    });
  }

  void _refresh() {
    setState(() {
      reportsFuture = _pedirReporte();
    });
  }

  void _openStylistDetail(ReportCommissionItem commission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StylistCommissionDetailSheet(commission: commission),
    );
  }

  void _openServiceDetail(ReportServiceSaleItem serviceSale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceSalesDetailSheet(serviceSale: serviceSale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reportes',
      subtitle: 'Resumen financiero, métodos de pago, arqueo de caja y comparación.',
      children: [
        // 1. Selector Temporal Rápido (Nivel 2)
        Card(
          elevation: 1,
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Text(
                      'Período del reporte: ${_formatDate(startDate)} al ${_formatDate(endDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined, size: 20),
                      onPressed: _refresh,
                      tooltip: 'Actualizar reporte',
                    ),
                  ],
                ),
                // Ambito del reporte (D-194). Solo tiene sentido con mas de
                // una sede: con una, seria un boton que no hace nada.
                if (widget.branches.length > 1) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.storefront_outlined, size: 16),
                        label: Text('Esta sede'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.public, size: 16),
                        label: Text('Todas las sedes'),
                      ),
                    ],
                    selected: {_consolidado},
                    onSelectionChanged: (s) => _cambiarAmbito(s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip('hoy', 'Hoy'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('semana', 'Esta semana'),
                      const SizedBox(width: 8),
                      _buildPeriodChip('mes', 'Este mes'),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          Icons.date_range_outlined,
                          size: 16,
                          color: selectedPeriod == 'rango' ? AppColors.brand : AppColors.textSecondary,
                        ),
                        label: Text(
                          selectedPeriod == 'rango' ? 'Rango: ${_formatDate(startDate)} - ${_formatDate(endDate)}' : 'Rango personalizado...',
                        ),
                        backgroundColor: selectedPeriod == 'rango' ? AppColors.brandTint : null,
                        side: BorderSide(
                          color: selectedPeriod == 'rango' ? AppColors.brand : AppColors.border,
                        ),
                        onPressed: _selectCustomDateRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Contenido del Reporte V3
        FutureBuilder<BranchReportV3>(
          future: reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                elevation: 1,
                color: AppColors.surface,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Calculando métricas y comparación...'),
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

            final report = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta 1: Rendimiento Financiero y Comparación
                _buildFinancialSummaryCard(report),
                const SizedBox(height: 16),

                // El desglose por sede (D-194). Va justo debajo del total: la
                // pregunta que sigue a "cuanto vendi" siempre es "y cual de
                // mis locales".
                if (report.esConsolidado) ...[
                  _buildDesglosePorSede(report),
                  const SizedBox(height: 16),
                ],

                // Tarjeta 2: Métodos de Pago y Arqueo de Efectivo
                _buildPaymentMethodsAndCashCard(report),
                const SizedBox(height: 16),

                // Tarjeta 3: Comisiones por Estilista
                _buildCommissionsSection(report),
                const SizedBox(height: 16),

                // Tarjeta 4: Ventas por Servicio y Estilista
                _buildSalesByServiceSection(report),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String periodKey, String label) {
    final isSelected = selectedPeriod == periodKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          _applyPeriod(periodKey);
        }
      },
    );
  }

  /// Cuanto puso cada sede en el consolidado (D-194).
  ///
  /// No cuesta una consulta extra: el consolidado calcula cada sede por
  /// separado y las suma, asi que este desglose ya estaba hecho.
  Widget _buildDesglosePorSede(BranchReportV3 report) {
    final sedes = [...report.byBranch]
      ..sort((a, b) => b.totalReceived.compareTo(a.totalReceived));

    final total = report.totalReceived;

    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cuánto puso cada sede',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                Text(
                  '${report.branchesCount} sedes',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final sede in sedes) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sede.branchName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _pesos(sede.totalReceived),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total <= 0 ? 0 : sede.totalReceived / total,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resultado ${_pesos(sede.netResult)} · '
                      '${sede.paymentsCount} cobros · '
                      'caja ${_pesos(sede.expectedCash)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 150000.0 -> "\$150.000". Los reportes manejan pesos enteros (D-175), asi
  /// que se redondea antes de partir en miles.
  String _pesos(double valor) {
    final entero = valor.round();
    final negativo = entero < 0;
    final digitos = entero.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      final restantes = digitos.length - i;
      buffer.write(digitos[i]);
      if (restantes > 1 && restantes % 3 == 1) buffer.write('.');
    }
    // El signo va ANTES del simbolo, no en medio: es el bug de TL-12, que
    // imprimia "\$-.100" al contar los puntos desde el final incluyendo el menos.
    return negativo ? '-\$$buffer' : '\$$buffer';
  }

  Widget _buildFinancialSummaryCard(BranchReportV3 report) {
    final isProfit = report.netResult >= 0;
    final growth = report.salesGrowthPercent;

    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionTitle('Resumen Financiero y Resultado'),
                const Spacer(),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: growth >= 0 ? AppColors.stateConfirmedTint : AppColors.stateToCollectTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          growth >= 0 ? Icons.trending_up : Icons.trending_down,
                          size: 16,
                          color: growth >= 0 ? AppColors.stateConfirmed : AppColors.stateToCollect,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          report.salesGrowthText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: growth >= 0 ? AppColors.stateConfirmed : AppColors.stateToCollect,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    report.salesGrowthText,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Métricas principales (Ingresos Cobrados vs Resultado Neto)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.point_of_sale_outlined, size: 18, color: AppColors.brand),
                            const SizedBox(width: 6),
                            const Text('Ingresos Cobrados', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.formattedTotalReceived,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandDeep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.paymentsCount} pagos en ${report.paidTicketsCount} tickets',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isProfit ? AppColors.stateConfirmedTint.withValues(alpha: 0.3) : AppColors.stateToCollectTint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isProfit ? AppColors.stateConfirmed.withValues(alpha: 0.4) : AppColors.stateToCollect.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isProfit ? Icons.savings_outlined : Icons.warning_amber_rounded,
                              size: 18,
                              color: isProfit ? AppColors.stateConfirmed : AppColors.stateToCollect,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isProfit ? 'Ganancia Neta' : 'Pérdida Neta',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isProfit ? AppColors.stateConfirmed : AppColors.stateToCollect,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.formattedNetResult,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isProfit ? AppColors.stateConfirmed : AppColors.stateToCollect,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tras compras, gastos y comisiones',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Desglose de Egresos Operativos
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSmallKpi('Compras Insumos', report.formattedTotalPurchases, Icons.shopping_cart_outlined, AppColors.textPrimary),
                _buildSmallKpi('Gastos Operativos', report.formattedTotalExpenses, Icons.receipt_outlined, AppColors.textPrimary),
                _buildSmallKpi('Comisiones Equipo', report.formattedTotalCommissions, Icons.badge_outlined, AppColors.brand),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsAndCashCard(BranchReportV3 report) {
    final total = report.totalReceived > 0 ? report.totalReceived : 1.0;

    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Métodos de Pago y Arqueo de Efectivo'),
            const SizedBox(height: 6),
            const Text(
              'Distribución de cobros por medio de pago y dinero físico esperado en caja.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Arqueo de caja
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandTint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 22, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Efectivo Esperado en Caja (Arqueo)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brandDeep),
                      ),
                      Text(
                        'Cobrado: ${report.formattedCashReceived}  -  Salidas: ${formatCOP(report.cashPurchases + report.cashExpenses)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    report.formattedExpectedCash,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Métodos discriminados con barras proporcionales
            _buildMethodRow('💵 Efectivo', report.cashReceived, report.formattedCashReceived, report.cashReceived / total, AppColors.success),
            const SizedBox(height: 10),
            _buildMethodRow('📱 Transferencias (Nequi / Daviplata)', report.transferReceived, report.formattedTransferReceived, report.transferReceived / total, AppColors.brand),
            const SizedBox(height: 10),
            _buildMethodRow('💳 Tarjetas / Datáfono', report.cardReceived, report.formattedCardReceived, report.cardReceived / total, AppColors.stateInProgress),
            if (report.otherReceived > 0) ...[
              const SizedBox(height: 10),
              _buildMethodRow('🔄 Otros medios', report.otherReceived, report.formattedOtherReceived, report.otherReceived / total, AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodRow(String label, double amount, String formatted, double ratio, Color color) {
    final percent = (ratio * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(
              '$formatted ($percent%)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceAlt,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionsSection(BranchReportV3 report) {
    final commissions = report.commissionsByStylist;

    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionTitle('Comisiones por Estilista'),
                const Spacer(),
                Text(
                  '${commissions.length} profesional(es)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (commissions.isEmpty)
              const Text(
                'No se generaron comisiones en este período.',
                style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              )
            else
              ...commissions.map(
                (c) => InkWell(
                  onTap: () => _openStylistDetail(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.brandTint,
                          child: Icon(Icons.person_outline, size: 18, color: AppColors.brandDeep),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.stylistName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandDeep,
                                ),
                              ),
                              Text(
                                '${c.servicesCount} servicio(s) · Ventas ${c.formattedServiceSales}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              c.formattedCommissionTotal,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            const Text(
                              'Comisión',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesByServiceSection(BranchReportV3 report) {
    final sales = report.salesByService;

    return Card(
      elevation: 1,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SectionTitle('Ventas por Servicio y Estilista'),
                const Spacer(),
                Text(
                  '${sales.length} línea(s)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (sales.isEmpty)
              const Text(
                'No hay tickets cerrados y cobrados en este período.',
                style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              )
            else
              ...sales.map(
                (s) => InkWell(
                  onTap: () => _openServiceDetail(s),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.spa_outlined, size: 20, color: AppColors.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.serviceName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandDeep,
                                ),
                              ),
                              Text(
                                'Estilista: ${s.stylistName} · ${s.ticketsCount} citas · ${s.totalDurationMinutes} min',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          s.formattedTotalSales,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StylistCommissionDetailSheet extends StatelessWidget {
  const _StylistCommissionDetailSheet({required this.commission});

  final ReportCommissionItem commission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandTint,
                child: Icon(Icons.person_outline, color: AppColors.brandDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commission.stylistName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const Text('Detalle de liquidación de comisión', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildDetailRow('Servicios Realizados:', '${commission.servicesCount} servicio(s)'),
          _buildDetailRow('Ventas Totales Producidas:', commission.formattedServiceSales),
          _buildDetailRow('Total Comisión a Pagar:', commission.formattedCommissionTotal, isBold: true, color: AppColors.success),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSalesDetailSheet extends StatelessWidget {
  const _ServiceSalesDetailSheet({required this.serviceSale});

  final ReportServiceSaleItem serviceSale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.spa_outlined, size: 28, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceSale.serviceName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    Text('Estilista: ${serviceSale.stylistName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildDetailRow('Citas / Tickets:', '${serviceSale.ticketsCount} citas'),
          _buildDetailRow('Duración Acumulada:', '${serviceSale.totalDurationMinutes} minutos (${(serviceSale.totalDurationMinutes / 60).toStringAsFixed(1)} horas)'),
          _buildDetailRow('Facturación Total:', serviceSale.formattedTotalSales, isBold: true, color: AppColors.success),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
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
