import 'package:flutter/material.dart';

import '../models/purchase_summary.dart';
import '../services/purchases_service.dart';
import '../widgets/app_widgets.dart';

class ComprasPage extends StatefulWidget {
  const ComprasPage({super.key});

  @override
  State<ComprasPage> createState() => _ComprasPageState();
}

class _ComprasPageState extends State<ComprasPage> {
  final PurchasesService _purchasesService = const PurchasesService();

  late Future<List<PurchaseSummary>> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _purchasesFuture = _purchasesService.getPurchasesSummary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PurchaseSummary>>(
      future: _purchasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar compras',
            description: snapshot.error.toString(),
          );
        }

        final purchases = snapshot.data ?? [];

        return _PurchasesContent(purchases: purchases);
      },
    );
  }
}

class _PurchasesContent extends StatelessWidget {
  final List<PurchaseSummary> purchases;

  const _PurchasesContent({
    required this.purchases,
  });

  @override
  Widget build(BuildContext context) {
    final totalPurchases = purchases.length;
    final totalAmount = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.totalAmount,
    );

    final suppliers = purchases
        .map((purchase) => purchase.supplierName)
        .toSet()
        .length;

    return AppPage(
      title: 'Compras',
      subtitle: 'Control de compras a proveedores e insumos.',
      children: [
        const InfoPanel(
          icon: Icons.shopping_cart_outlined,
          title: 'Compras del negocio',
          description:
              'Aquí se muestran las compras registradas para alimentar inventario y controlar proveedores.',
        ),
        const SizedBox(height: 16),
        _PurchasesSummaryCard(
          totalPurchases: totalPurchases,
          totalAmount: totalAmount,
          suppliers: suppliers,
        ),
        const SizedBox(height: 16),
        const SectionTitle('Compras registradas'),
        const SizedBox(height: 12),
        _PurchasesTable(purchases: purchases),
      ],
    );
  }
}

class _PurchasesSummaryCard extends StatelessWidget {
  final int totalPurchases;
  final double totalAmount;
  final int suppliers;

  const _PurchasesSummaryCard({
    required this.totalPurchases,
    required this.totalAmount,
    required this.suppliers,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          title: 'Compras',
          value: '$totalPurchases',
          description: 'Facturas registradas',
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          title: 'Total comprado',
          value: '\$${totalAmount.toStringAsFixed(0)}',
          description: 'Valor total registrado',
          icon: Icons.attach_money,
        ),
        MetricCard(
          title: 'Proveedores',
          value: '$suppliers',
          description: 'Proveedores distintos',
          icon: Icons.local_shipping_outlined,
        ),
      ],
    );
  }
}

class _PurchasesTable extends StatelessWidget {
  final List<PurchaseSummary> purchases;

  const _PurchasesTable({
    required this.purchases,
  });

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin compras registradas',
        description: 'Todavía no hay compras cargadas en el sistema.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Proveedor')),
              DataColumn(label: Text('Factura')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Pago')),
              DataColumn(label: Text('Notas')),
            ],
            rows: [
              for (final purchase in purchases)
                DataRow(
                  cells: [
                    DataCell(Text(purchase.purchaseDate)),
                    DataCell(Text(purchase.supplierName)),
                    DataCell(Text(purchase.invoiceText)),
                    DataCell(Text(purchase.formattedTotalAmount)),
                    DataCell(Text(purchase.paymentMethodText)),
                    DataCell(
                      SizedBox(
                        width: 280,
                        child: Text(
                          purchase.notesText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
