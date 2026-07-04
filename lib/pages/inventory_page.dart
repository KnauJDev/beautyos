import 'package:flutter/material.dart';

import '../models/inventory_movement_summary.dart';
import '../models/product_summary.dart';
import '../services/inventory_movements_service.dart';
import '../services/products_service.dart';
import '../widgets/app_widgets.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final ProductsService productsService = const ProductsService();
  final InventoryMovementsService movementsService =
      const InventoryMovementsService();

  late final Future<_InventoryPageData> inventoryFuture;

  @override
  void initState() {
    super.initState();
    inventoryFuture = _loadInventoryData();
  }

  Future<_InventoryPageData> _loadInventoryData() async {
    final products = await productsService.getProductsSummary();
    final movements = await movementsService.getInventoryMovementsSummary();

    return _InventoryPageData(
      products: products,
      movements: movements,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Inventario',
      subtitle: 'Productos, insumos y control de stock.',
      children: [
        const InfoPanel(
          icon: Icons.inventory_2_outlined,
          title: 'Inventario conectado a Supabase',
          description:
              'Aquí veremos productos para venta, insumos internos, cantidades actuales, mínimos de stock, precios base y movimientos recientes.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<_InventoryPageData>(
          future: inventoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudo cargar el inventario',
                description:
                    'Revisa la conexión con Supabase o las funciones de inventario.',
              );
            }

            final data = snapshot.data;

            if (data == null) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin datos de inventario',
                description:
                    'Todavía no hay productos ni movimientos para mostrar.',
              );
            }

            return _InventoryContent(data: data);
          },
        ),
      ],
    );
  }
}

class _InventoryContent extends StatelessWidget {
  final _InventoryPageData data;

  const _InventoryContent({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Resumen de inventario'),
        ProductsList(products: data.products),
        const SizedBox(height: 16),
        const SectionTitle('Movimientos recientes'),
        MovementsList(movements: data.movements),
      ],
    );
  }
}

class ProductsList extends StatelessWidget {
  final List<ProductSummary> products;

  const ProductsList({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin productos registrados',
        description: 'Todavía no hay productos o insumos activos para mostrar.',
      );
    }

    final saleProducts = products
        .where((product) => product.productType == 'sale')
        .length;

    final consumables = products
        .where((product) => product.productType != 'sale')
        .length;

    final lowStockProducts = products
        .where((product) => product.isLowStock)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InventorySummaryCard(
          totalProducts: products.length,
          saleProducts: saleProducts,
          consumables: consumables,
          lowStockProducts: lowStockProducts,
        ),
        const SizedBox(height: 12),
        ProductsTable(products: products),
      ],
    );
  }
}

class MovementsList extends StatelessWidget {
  final List<InventoryMovementSummary> movements;

  const MovementsList({
    super.key,
    required this.movements,
  });

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin movimientos registrados',
        description:
            'Todavía no hay entradas, consumos, ventas u otros movimientos.',
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
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Costo')),
              DataColumn(label: Text('Notas')),
            ],
            rows: [
              for (final movement in movements)
                DataRow(
                  cells: [
                    DataCell(Text(movement.createdDateText)),
                    DataCell(Text(movement.productName)),
                    DataCell(Text(movement.movementTypeText)),
                    DataCell(Text(movement.quantityText)),
                    DataCell(Text(movement.formattedUnitCost)),
                    DataCell(
                      SizedBox(
                        width: 260,
                        child: Text(
                          movement.notes,
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
class InventorySummaryCard extends StatelessWidget {
  final int totalProducts;
  final int saleProducts;
  final int consumables;
  final int lowStockProducts;

  const InventorySummaryCard({
    super.key,
    required this.totalProducts,
    required this.saleProducts,
    required this.consumables,
    required this.lowStockProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _InventoryMetric(label: 'Productos', value: '$totalProducts'),
            _InventoryMetric(label: 'Para venta', value: '$saleProducts'),
            _InventoryMetric(label: 'Insumos', value: '$consumables'),
            _InventoryMetric(label: 'Stock bajo', value: '$lowStockProducts'),
          ],
        ),
      ),
    );
  }
}

class ProductsTable extends StatelessWidget {
  final List<ProductSummary> products;

  const ProductsTable({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Mínimo')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Compra')),
              DataColumn(label: Text('Venta')),
            ],
            rows: [
              for (final product in products)
                DataRow(
                  cells: [
                    DataCell(Text(product.name)),
                    DataCell(Text(product.category)),
                    DataCell(Text(product.productTypeText)),
                    DataCell(Text(product.stockText)),
                    DataCell(Text(product.minimumStockText)),
                    DataCell(Text(product.stockStatusText)),
                    DataCell(Text(product.formattedPurchasePrice)),
                    DataCell(
                      Text(
                        product.visibleForSale
                            ? product.formattedSalePrice
                            : 'No aplica',
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
class MovementCard extends StatelessWidget {
  final InventoryMovementSummary movement;

  const MovementCard({
    super.key,
    required this.movement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              movement.productName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('${movement.productCategory} · ${movement.movementTypeText}'),
            const SizedBox(height: 12),
            _ProductLine(label: 'Cantidad', value: movement.quantityText),
            _ProductLine(label: 'Costo unitario', value: movement.formattedUnitCost),
            _ProductLine(label: 'Fecha', value: movement.createdDateText),
            _ProductLine(label: 'Notas', value: movement.notes),
          ],
        ),
      ),
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InventoryMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _ProductLine extends StatelessWidget {
  final String label;
  final String value;

  const _ProductLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _InventoryPageData {
  final List<ProductSummary> products;
  final List<InventoryMovementSummary> movements;

  const _InventoryPageData({
    required this.products,
    required this.movements,
  });
}



