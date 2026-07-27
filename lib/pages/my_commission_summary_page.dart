import 'package:flutter/material.dart';

import '../models/my_commission_summary_item.dart';
import '../services/my_commission_summary_service.dart';
import '../widgets/app_widgets.dart';

class MyCommissionSummaryPage extends StatefulWidget {
  const MyCommissionSummaryPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<MyCommissionSummaryPage> createState() =>
      _MyCommissionSummaryPageState();
}

class _MyCommissionSummaryPageState extends State<MyCommissionSummaryPage> {
  late final MyCommissionSummaryService summaryService;

  late DateTime startDate;
  late DateTime endDate;
  late Future<List<MyCommissionSummaryItem>> summaryFuture;

  bool showMoney = false;

  @override
  void initState() {
    super.initState();
    summaryService = MyCommissionSummaryService(branchId: widget.branchId);

    final today = DateUtils.dateOnly(DateTime.now());
    startDate = DateTime(today.year, today.month, 1);
    endDate = today;
    summaryFuture = _load();
  }

  Future<List<MyCommissionSummaryItem>> _load() {
    return summaryService.getMySummary(startDate: startDate, endDate: endDate);
  }

  void _refresh() {
    setState(() {
      summaryFuture = _load();
    });
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 5, 12, 31),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      helpText: 'Selecciona el rango a consultar',
      cancelText: 'Cancelar',
      confirmText: 'Ver comisiones',
    );

    if (pickedRange != null) {
      setState(() {
        startDate = DateUtils.dateOnly(pickedRange.start);
        endDate = DateUtils.dateOnly(pickedRange.end);
        summaryFuture = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mi panel financiero',
      subtitle: 'Lo que te ha generado cada servicio que has prestado.',
      children: [
        _RangeSelector(
          startDate: startDate,
          endDate: endDate,
          onPickRange: _pickRange,
          onRefresh: _refresh,
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<MyCommissionSummaryItem>>(
          future: summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No pudimos cargar tu panel financiero',
                description: snapshot.error.toString(),
              );
            }

            final items = snapshot.data ?? <MyCommissionSummaryItem>[];

            if (items.isEmpty) {
              return InfoPanel(
                icon: Icons.payments_outlined,
                title: 'Sin comisiones en este rango',
                description:
                    'No tienes comisiones generadas entre '
                    '${_formatShort(startDate)} y ${_formatShort(endDate)}.',
              );
            }

            final totalCommission = items.fold<double>(
              0,
              (sum, item) => sum + item.commissionTotal,
            );
            final totalServices = items.fold<int>(
              0,
              (sum, item) => sum + item.servicesCount,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      icon: Icons.event_available_outlined,
                      title: 'Servicios prestados',
                      value: totalServices.toString(),
                      description: 'En el rango seleccionado',
                    ),
                    _TotalCommissionCard(
                      total: totalCommission,
                      showMoney: showMoney,
                      onToggle: () {
                        setState(() {
                          showMoney = !showMoney;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionTitle('Desglose por servicio'),
                const SizedBox(height: 12),
                _CommissionTable(items: items, showMoney: showMoney),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _formatShort(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.startDate,
    required this.endDate,
    required this.onPickRange,
    required this.onRefresh,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickRange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${_formatShort(startDate)} - ${_formatShort(endDate)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCommissionCard extends StatelessWidget {
  const _TotalCommissionCard({
    required this.total,
    required this.showMoney,
    required this.onToggle,
  });

  final double total;
  final bool showMoney;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final amountText = showMoney ? _formatMoney(total) : '••••••';

    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF5F3FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: Color(0xFF7C3AED)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total comisiones',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      amountText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: showMoney ? 'Ocultar cifra' : 'Mostrar cifra',
                onPressed: onToggle,
                icon: Icon(
                  showMoney
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;

      buffer.write(rounded[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }
}

class _CommissionTable extends StatelessWidget {
  const _CommissionTable({required this.items, required this.showMoney});

  final List<MyCommissionSummaryItem> items;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Servicio')),
            DataColumn(label: Text('Veces prestado')),
            DataColumn(label: Text('Comisión')),
          ],
          rows: items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.serviceName)),
                    DataCell(Text(item.servicesCount.toString())),
                    DataCell(
                      Text(
                        showMoney ? item.formattedCommissionTotal : '••••••',
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
