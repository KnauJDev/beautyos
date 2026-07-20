import 'package:flutter/material.dart';

import '../models/purchase_item_summary.dart';
import '../models/purchase_summary.dart';
import '../services/purchase_items_service.dart';
import '../services/purchases_service.dart';
import '../widgets/app_widgets.dart';

class ComprasPage extends StatefulWidget {
  const ComprasPage({super.key, required this.branchId});

  final String? branchId;

  @override
  State<ComprasPage> createState() => _ComprasPageState();
}

class _ComprasPageState extends State<ComprasPage> {
  late final PurchasesService _purchasesService;
  late final PurchaseItemsService _purchaseItemsService;

  late Future<_PurchasesPageData> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _purchasesService = PurchasesService(branchId: widget.branchId);
    _purchaseItemsService = PurchaseItemsService(branchId: widget.branchId);
    _purchasesFuture = _loadPurchasesData();
  }

  Future<_PurchasesPageData> _loadPurchasesData() async {
    final purchases = await _purchasesService.getPurchasesSummary();
    final items = await _purchaseItemsService.getPurchaseItemsSummary();

    return _PurchasesPageData(
      purchases: purchases,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PurchasesPageData>(
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

        final data = snapshot.data ??
            const _PurchasesPageData(
              purchases: [],
              items: [],
            );

        return _PurchasesContent(data: data);
      },
    );
  }
}

class _PurchasesContent extends StatelessWidget {
  final _PurchasesPageData data;

  const _PurchasesContent({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final purchases = data.purchases;
    final items = data.items;

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
              'Aqui se muestran las compras registradas para alimentar inventario y controlar proveedores.',
        ),
        const SizedBox(height: 16),
        _PurchasesSummaryCard(
          totalPurchases: totalPurchases,
          totalAmount: totalAmount,
          suppliers: suppliers,
          itemLines: items.length,
        ),
        const SizedBox(height: 16),
        const SectionTitle('Compras registradas'),
        const SizedBox(height: 12),
        _PurchasesTable(purchases: purchases),
        const SizedBox(height: 24),
        const SectionTitle('Detalle de productos comprados'),
        const SizedBox(height: 12),
        _PurchaseItemsTable(items: items),
      ],
    );
  }
}

class _PurchasesSummaryCard extends StatelessWidget {
  final int totalPurchases;
  final double totalAmount;
  final int suppliers;
  final int itemLines;

  const _PurchasesSummaryCard({
    required this.totalPurchases,
    required this.totalAmount,
    required this.suppliers,
    required this.itemLines,
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
        MetricCard(
          title: 'Productos',
          value: '$itemLines',
          description: 'Lineas de detalle',
          icon: Icons.inventory_2_outlined,
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
        description: 'Todavia no hay compras cargadas en el sistema.',
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

class _PurchaseItemsTable extends StatelessWidget {
  final List<PurchaseItemSummary> items;

  const _PurchaseItemsTable({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin detalle de compras',
        description:
            'Todavia no hay productos asociados a las compras registradas.',
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
              DataColumn(label: Text('Factura')),
              DataColumn(label: Text('Proveedor')),
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Categoria')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Costo unitario')),
              DataColumn(label: Text('Subtotal')),
              DataColumn(label: Text('Notas')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(Text(item.purchaseDate)),
                    DataCell(Text(item.invoiceText)),
                    DataCell(Text(item.supplierName)),
                    DataCell(Text(item.productName)),
                    DataCell(Text(item.productCategory)),
                    DataCell(Text(item.quantityText)),
                    DataCell(Text(item.formattedUnitCost)),
                    DataCell(Text(item.formattedLineTotal)),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(
                          item.notesText,
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

class _PurchasesPageData {
  final List<PurchaseSummary> purchases;
  final List<PurchaseItemSummary> items;

  const _PurchasesPageData({
    required this.purchases,
    required this.items,
  });
}
