import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/inventory_movement_summary.dart';
import '../models/product_management_item.dart';
import '../services/inventory_movements_service.dart';
import '../services/low_stock_alert_service.dart';
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

  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, out_of_stock, low_stock, normal, consumable, sale, inactive

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
        branchId: widget.branchId,
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

  List<ProductManagementItem> _filterProducts(List<ProductManagementItem> products) {
    return products.where((p) {
      // 1. Filtro por estado / categoría
      switch (_selectedFilter) {
        case 'out_of_stock':
          if (!p.active || p.currentStock > 0) return false;
          break;
        case 'low_stock':
          if (!p.active || !p.isLowStock || p.currentStock <= 0) return false;
          break;
        case 'normal':
          if (!p.active || p.isLowStock) return false;
          break;
        case 'consumable':
          if (!p.active || p.productType == 'sale') return false;
          break;
        case 'sale':
          if (!p.active || p.productType != 'sale') return false;
          break;
        case 'inactive':
          if (p.active) return false;
          break;
        case 'all':
        default:
          if (!p.active && _selectedFilter != 'inactive') return false;
          break;
      }

      // 2. Filtro por texto
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = p.name.toLowerCase().contains(query);
        final brandMatch = (p.brand ?? '').toLowerCase().contains(query);
        final categoryMatch = p.category.toLowerCase().contains(query);
        final skuMatch = (p.sku ?? '').toLowerCase().contains(query);
        if (!nameMatch && !brandMatch && !categoryMatch && !skuMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Inventario',
      subtitle: 'Productos, insumos y control de stock.',
      children: [
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
              return Card(
                color: AppColors.surface,
                child: const Padding(
                  padding: EdgeInsets.all(24),
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

            final allProducts = snapshot.data ?? [];
            final activeProducts = allProducts.where((p) => p.active).toList();
            final outOfStockCount = activeProducts.where((p) => p.currentStock <= 0).length;
            final lowStockCount = activeProducts.where((p) => p.isLowStock && p.currentStock > 0).length;
            final normalStockCount = activeProducts.where((p) => !p.isLowStock).length;
            final consumablesCount = activeProducts.where((p) => p.productType != 'sale').length;
            final saleCount = activeProducts.where((p) => p.productType == 'sale').length;
            final inactiveCount = allProducts.where((p) => !p.active).length;

            final filteredProducts = _filterProducts(allProducts);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen general de inventario
                InventorySummaryCard(
                  totalProducts: activeProducts.length,
                  saleProducts: saleCount,
                  consumables: consumablesCount,
                  lowStockProducts: outOfStockCount + lowStockCount,
                ),
                const SizedBox(height: 16),

                // Buscador y Chips de Filtro (Nivel 2)
                Card(
                  elevation: 1,
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por producto, marca, categoría o SKU...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value.trim()),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'Todos (${activeProducts.length})'),
                              const SizedBox(width: 8),
                              if (outOfStockCount > 0) ...[
                                _buildFilterChip('out_of_stock', '🔴 Agotados ($outOfStockCount)'),
                                const SizedBox(width: 8),
                              ],
                              _buildFilterChip('low_stock', '⚠️ Stock bajo ($lowStockCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('normal', '🟢 Normal ($normalStockCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('consumable', '📦 Insumos ($consumablesCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('sale', '🛍️ Para venta ($saleCount)'),
                              if (inactiveCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildFilterChip('inactive', '⚪ Inactivos ($inactiveCount)'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Listado de Productos
                Card(
                  elevation: 1,
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SectionTitle('Productos'),
                            const Spacer(),
                            Text(
                              '${filteredProducts.length} producto(s)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filteredProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No hay productos que coincidan con la búsqueda o filtro.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedFilter = 'all';
                                      });
                                    },
                                    child: const Text('Limpiar filtros'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredProducts.map(
                            (product) => ProductRow(
                              product: product,
                              onEdit: () => openEditProductDialog(product),
                              onToggleActive: () => toggleActive(product),
                              onConsume: () => openConsumeStockDialog(product),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle('Movimientos recientes'),
        FutureBuilder<List<InventoryMovementSummary>>(
          future: movementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                color: AppColors.surface,
                child: const Padding(
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = key);
        }
      },
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
    final isOutOfStock = product.currentStock <= 0;
    final isLowStock = product.isLowStock && !isOutOfStock;

    Color stockColor = AppColors.stateConfirmed;
    String stockLabel = 'Stock normal';
    if (!product.active) {
      stockColor = AppColors.textMuted;
      stockLabel = 'Inactivo';
    } else if (isOutOfStock) {
      stockColor = AppColors.stateToCollect;
      stockLabel = 'Agotado';
    } else if (isLowStock) {
      stockColor = AppColors.statePending;
      stockLabel = 'Stock bajo';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutOfStock && product.active
              ? AppColors.stateToCollect.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: product.productType == 'sale'
                ? AppColors.brandTint
                : AppColors.surface,
            child: Icon(
              product.productType == 'sale'
                  ? Icons.shopping_bag_outlined
                  : Icons.inventory_2_outlined,
              size: 18,
              color: product.active ? AppColors.brandDeep : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.brand != null && product.brand!.trim().isNotEmpty
                            ? '${product.name} · ${product.brand}'
                            : product.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: product.active ? AppColors.brandDeep : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stockLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.category} · ${product.productTypeText} · '
                  '${product.stockText} (mín. ${product.minimumStockText})'
                  '${product.sku != null && product.sku!.isNotEmpty ? ' · SKU: ${product.sku}' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Costo compra ${product.formattedPurchasePrice} · Venta '
                  '${product.visibleForSale ? product.formattedSalePrice : 'no aplica'}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  ? AppColors.danger
                  : AppColors.success,
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
      color: AppColors.surface,
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
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _InventoryMetric(label: 'Productos activos', value: '$totalProducts'),
            _InventoryMetric(label: 'Para venta', value: '$saleProducts'),
            _InventoryMetric(label: 'Insumos', value: '$consumables'),
            _InventoryMetric(label: 'Stock bajo o agotado', value: '$lowStockProducts'),
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
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.brandDeep,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
  late final brandController = TextEditingController(
    text: widget.existing?.brand ?? '',
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
    brandController.dispose();
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
    final brand = brandController.text.trim();
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
          brand: brand.isEmpty ? null : brand,
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
          brand: brand.isEmpty ? null : brand,
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
            TextField(
              controller: brandController,
              decoration: const InputDecoration(labelText: 'Marca (opcional)'),
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
                'se carga registrando una compra.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
    required this.branchId,
    required this.movementsService,
    required this.product,
  });

  final String branchId;
  final InventoryMovementsService movementsService;
  final ProductManagementItem product;

  @override
  State<_StockConsumptionDialog> createState() =>
      _StockConsumptionDialogState();
}

class _StockConsumptionDialogState extends State<_StockConsumptionDialog> {
  final quantityController = TextEditingController();
  final notesController = TextEditingController();
  final lowStockAlertService = const LowStockAlertService();
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

      unawaited(
        lowStockAlertService.maybeSendAlert(
          branchId: widget.branchId,
          productId: widget.product.id,
        ),
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
              style: const TextStyle(color: AppColors.textSecondary),
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
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
