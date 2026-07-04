import 'package:flutter/material.dart';

import '../models/product_summary.dart';
import '../services/products_service.dart';
import '../widgets/app_widgets.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final ProductsService productsService = const ProductsService();

  late final Future<List<ProductSummary>> productsFuture;

  @override
  void initState() {
    super.initState();
    productsFuture = productsService.getProductsSummary();
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
              'Aquí veremos productos para venta, insumos internos, cantidades actuales, mínimos de stock y precios base.',
        ),
        const SizedBox(height: 16),
        const SectionTitle('Productos e insumos'),
        FutureBuilder<List<ProductSummary>>(
          future: productsFuture,
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
                    'Revisa la conexión con Supabase o la función get_products_summary.',
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return const InfoPanel(
                icon: Icons.info_outline,
                title: 'Sin productos registrados',
                description:
                    'Todavía no hay productos o insumos activos para mostrar.',
              );
            }

            return ProductsList(products: products);
          },
        ),
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
        for (final product in products) ProductCard(product: product),
      ],
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

class ProductCard extends StatelessWidget {
  final ProductSummary product;

  const ProductCard({
    super.key,
    required this.product,
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
              product.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('${product.category} · ${product.productTypeText}'),
            const SizedBox(height: 12),
            _ProductLine(label: 'Stock actual', value: product.stockText),
            _ProductLine(label: 'Stock mínimo', value: product.minimumStockText),
            _ProductLine(label: 'Estado', value: product.stockStatusText),
            _ProductLine(
              label: 'Precio compra',
              value: product.formattedPurchasePrice,
            ),
            _ProductLine(
              label: 'Precio venta',
              value: product.visibleForSale
                  ? product.formattedSalePrice
                  : 'No aplica',
            ),
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
