import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_movement_summary.dart';
import '../models/product_management_item.dart';
import '../services/inventory_movements_service.dart';
import '../services/products_service.dart';
import '../widgets/app_widgets.dart';

const List<String> kProductTypes = ['consumable', 'sale'];

String productTypeLabel(String value) {
  return value == 'sale' ? 'Producto para venta' : 'Insumo interno';
}

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  late final ProductsService productsService;
  late final InventoryMovementsService movementsService;

  late Future<List<ProductManagementItem>> productsFuture;
  late Future<List<InventoryMovementSummary>> movementsFuture;

  @override
  void initState() {
    super.initState();
    productsService = ProductsService(branchId: widget.branchId);
    movementsService = InventoryMovementsService(branchId: widget.branchId);
    productsFuture = productsService.getProductsForManagement();
    movementsFuture = movementsService.getInventoryMovementsSummary();
  }

  void reloadProducts() {
    setState(() {
      productsFuture = productsService.getProductsForManagement();
    });
  }

  void reloadProductsAndMovements() {
    setState(() {
      productsFuture = productsService.getProductsForManagement();
      movementsFuture = movementsService.getInventoryMovementsSummary();
    });
  }

  Future<void> openConsumeStockDialog(ProductManagementItem product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StockConsumptionDialog(
        movementsService: movementsService,
        product: product,
      ),
    );

    if (saved == true) reloadProductsAndMovements();
  }

  Future<void> openCreateProductDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        productsService: productsService,
        existing: null,
      ),
    );

    if (saved == true) reloadProducts();
  }

  Future<void> openEditProductDialog(ProductManagementItem product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        productsService: productsService,
        existing: product,
      ),
    );

    if (saved == true) reloadProducts();
  }

  Future<void> toggleActive(ProductManagementItem product) async {
    try {
      await productsService.setProductActive(
        productId: product.id,
        active: !product.active,
      );
      reloadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    }
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
              'Crea, edita o desactiva productos para venta e insumos internos. El stock sube al registrar una compra y baja al registrar un consumo interno; aquí se ajustan nombre, categoría, precios y mínimos.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: openCreateProductDialog,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Agregar producto'),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ProductManagementItem>>(
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
              return InfoPanel(
                icon: Icons.error_outline,
                title: 'No se pudo cargar el inventario',
                description: snapshot.error.toString(),
              );
            }

            final products = snapshot.data ?? [];

            return _ProductsSection(
              products: products,
              onEdit: openEditProductDialog,
              onToggleActive: toggleActive,
              onConsume: openConsumeStockDialog,
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Movimientos recientes'),
        FutureBuilder<List<InventoryMovementSummary>>(
          future: movementsFuture,
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
                title: 'No se pudieron cargar los movimientos',
                description:
                    'Revisa la conexión con Supabase o las funciones de inventario.',
              );
            }

            return MovementsList(movements: snapshot.data ?? []);
          },
        ),
      ],
    );
  }
}

class _ProductsSection extends StatelessWidget {
  final List<ProductManagementItem> products;
  final void Function(ProductManagementItem) onEdit;
  final void Function(ProductManagementItem) onToggleActive;
  final void Function(ProductManagementItem) onConsume;

  const _ProductsSection({
    required this.products,
    required this.onEdit,
    required this.onToggleActive,
    required this.onConsume,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin productos registrados',
        description:
            'No hay productos para mostrar. Usa "Agregar producto" para crear el primero.',
      );
    }

    final activeProducts = products.where((product) => product.active);
    final saleProducts = activeProducts
        .where((product) => product.productType == 'sale')
        .length;
    final consumables = activeProducts
        .where((product) => product.productType != 'sale')
        .length;
    final lowStockProducts = activeProducts
        .where((product) => product.isLowStock)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InventorySummaryCard(
          totalProducts: activeProducts.length,
          saleProducts: saleProducts,
          consumables: consumables,
          lowStockProducts: lowStockProducts,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Productos'),
                const SizedBox(height: 14),
                ...products.map(
                  (product) => ProductRow(
                    product: product,
                    onEdit: () => onEdit(product),
                    onToggleActive: () => onToggleActive(product),
                    onConsume: () => onConsume(product),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProductRow extends StatelessWidget {
  final ProductManagementItem product;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onConsume;

  const ProductRow({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onToggleActive,
    required this.onConsume,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = product.active
        ? const Color(0xFF2D1B69)
        : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            product.active
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
            size: 22,
            color: product.active
                ? const Color(0xFF7C3AED)
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.category} · ${product.productTypeText} · '
                  '${product.stockText} (mín. ${product.minimumStockText})'
                  '${product.active ? '' : ' · inactivo'}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compra ${product.formattedPurchasePrice} · Venta '
                  '${product.visibleForSale ? product.formattedSalePrice : 'no aplica'}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (product.active)
            IconButton(
              tooltip: 'Registrar consumo interno',
              onPressed: product.currentStock > 0 ? onConsume : null,
              icon: const Icon(Icons.remove_shopping_cart_outlined, size: 20),
            ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: product.active ? 'Desactivar' : 'Reactivar',
            onPressed: onToggleActive,
            icon: Icon(
              product.active
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 20,
              color: product.active
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}

class MovementsList extends StatelessWidget {
  final List<InventoryMovementSummary> movements;

  const MovementsList({super.key, required this.movements});

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
            _InventoryMetric(label: 'Productos activos', value: '$totalProducts'),
            _InventoryMetric(label: 'Para venta', value: '$saleProducts'),
            _InventoryMetric(label: 'Insumos', value: '$consumables'),
            _InventoryMetric(label: 'Stock bajo', value: '$lowStockProducts'),
          ],
        ),
      ),
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InventoryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.productsService,
    required this.existing,
  });

  final ProductsService productsService;
  final ProductManagementItem? existing;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final categoryController = TextEditingController(
    text: widget.existing?.category ?? '',
  );
  late final unitController = TextEditingController(
    text: widget.existing?.unit ?? 'unidad',
  );
  late final skuController = TextEditingController(
    text: widget.existing?.sku ?? '',
  );
  late final minimumStockController = TextEditingController(
    text: widget.existing?.minimumStock.toString() ?? '0',
  );
  late final purchasePriceController = TextEditingController(
    text: widget.existing?.purchasePrice.toString() ?? '',
  );
  late final salePriceController = TextEditingController(
    text: widget.existing?.salePrice.toString() ?? '',
  );
  late String productType = widget.existing?.productType ?? 'consumable';
  late bool visibleForSale = widget.existing?.visibleForSale ?? false;
  bool isSaving = false;
  String? errorMessage;

  bool get isEditing => widget.existing != null;

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    unitController.dispose();
    skuController.dispose();
    minimumStockController.dispose();
    purchasePriceController.dispose();
    salePriceController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    final unit = unitController.text.trim();
    final sku = skuController.text.trim();
    final minimumStock = num.tryParse(minimumStockController.text.trim());
    final purchasePrice = num.tryParse(purchasePriceController.text.trim());
    final salePrice = num.tryParse(salePriceController.text.trim());

    if (name.isEmpty) {
      setState(() => errorMessage = 'El nombre es obligatorio.');
      return;
    }
    if (minimumStock == null || minimumStock < 0) {
      setState(() => errorMessage = 'El stock mínimo debe ser un número válido.');
      return;
    }
    if (purchasePrice == null || purchasePrice < 0) {
      setState(() => errorMessage = 'El costo de compra debe ser un número válido.');
      return;
    }
    if (salePrice == null || salePrice < 0) {
      setState(() => errorMessage = 'El precio de venta debe ser un número válido.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      if (isEditing) {
        await widget.productsService.updateProduct(
          productId: widget.existing!.id,
          name: name,
          category: category,
          productType: productType,
          unit: unit.isEmpty ? 'unidad' : unit,
          sku: sku.isEmpty ? null : sku,
          minimumStock: minimumStock,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          visibleForSale: visibleForSale,
        );
      } else {
        await widget.productsService.createProduct(
          name: name,
          category: category,
          productType: productType,
          unit: unit.isEmpty ? 'unidad' : unit,
          sku: sku.isEmpty ? null : sku,
          minimumStock: minimumStock,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          visibleForSale: visibleForSale,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Editar producto' : 'Agregar producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: productType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: kProductTypes
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(productTypeLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => productType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unidad (ej. unidad, ml, gr)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: skuController,
              decoration: const InputDecoration(labelText: 'SKU (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minimumStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock mínimo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: purchasePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Costo de compra (COP)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio de venta (COP)'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para venta al cliente'),
              value: visibleForSale,
              onChanged: (value) => setState(() => visibleForSale = value),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 8),
              const Text(
                'El producto se crea con 0 unidades en stock. El stock inicial '
                'se carga registrando una compra (próximo bloque).',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _StockConsumptionDialog extends StatefulWidget {
  const _StockConsumptionDialog({
    required this.movementsService,
    required this.product,
  });

  final InventoryMovementsService movementsService;
  final ProductManagementItem product;

  @override
  State<_StockConsumptionDialog> createState() =>
      _StockConsumptionDialogState();
}

class _StockConsumptionDialogState extends State<_StockConsumptionDialog> {
  final quantityController = TextEditingController();
  final notesController = TextEditingController();
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    quantityController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantity = num.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      setState(() => errorMessage = 'La cantidad debe ser mayor a cero.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.movementsService.createStockConsumption(
        productId: widget.product.id,
        quantity: quantity,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => errorMessage = error.message);
    } catch (error) {
      setState(() => errorMessage = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar consumo interno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.product.name} · disponible: ${widget.product.stockText}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad a descontar (${widget.product.unit})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Esto solo descuenta el stock y queda en el historial de '
              'movimientos. No afecta el reporte financiero.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
