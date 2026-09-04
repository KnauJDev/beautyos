import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/product_management_item.dart';
import '../models/purchase_item_summary.dart';
import '../models/purchase_management_item.dart';
import '../services/my_profile_service.dart';
import '../services/products_service.dart';
import '../services/purchase_items_service.dart';
import '../services/purchases_service.dart';
import '../widgets/app_widgets.dart';

const List<String> kPaymentMethods = ['cash', 'transfer', 'card', 'credit', 'other'];

String paymentMethodLabel(String value) {
  switch (value) {
    case 'cash':
      return 'Efectivo';
    case 'transfer':
      return 'Transferencia';
    case 'card':
      return 'Tarjeta';
    case 'credit':
      return 'Crédito';
    case 'other':
      return 'Otro';
    default:
      return value;
  }
}

class ComprasPage extends StatefulWidget {
  const ComprasPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<ComprasPage> createState() => _ComprasPageState();
}

class _ComprasPageState extends State<ComprasPage> {
  late final PurchasesService _purchasesService;
  late final PurchaseItemsService _purchaseItemsService;
  late final ProductsService _productsService;
  final MyProfileService _myProfileService = const MyProfileService();

  late Future<_PurchasesPageData> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _purchasesService = PurchasesService(branchId: widget.branchId);
    _purchaseItemsService = PurchaseItemsService(branchId: widget.branchId);
    _productsService = ProductsService(branchId: widget.branchId);
    _purchasesFuture = _loadPurchasesData();
  }

  Future<_PurchasesPageData> _loadPurchasesData() async {
    final purchases = await _purchasesService.getPurchasesForManagement();
    final items = await _purchaseItemsService.getPurchaseItemsSummary();
    final profile = await _myProfileService.getMyProfile();

    return _PurchasesPageData(
      purchases: purchases,
      items: items,
      isOwner: profile?.role == 'owner',
    );
  }

  void _reload() {
    setState(() {
      _purchasesFuture = _loadPurchasesData();
    });
  }

  Future<void> _openCreatePurchaseDialog() async {
    final products = await _productsService.getProductsForManagement();
    final activeProducts = products.where((p) => p.active).toList();

    if (!mounted) return;

    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero crea al menos un producto activo en Inventario.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PurchaseFormDialog(
        purchasesService: _purchasesService,
        products: activeProducts,
      ),
    );

    if (saved == true) _reload();
  }

  Future<void> _openEditHeaderDialog(PurchaseManagementItem purchase) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PurchaseHeaderDialog(
        purchasesService: _purchasesService,
        existing: purchase,
      ),
    );

    if (saved == true) _reload();
  }

  Future<void> _voidPurchase(PurchaseManagementItem purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular compra'),
        content: Text(
          'Se anulará la compra de "${purchase.supplierName}" y se revertirá '
          'el stock y el costo promedio que generó. Esta acción no se puede '
          'deshacer. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _purchasesService.voidPurchase(purchaseId: purchase.id);
      _reload();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo anular: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PurchasesPageData>(
      future: _purchasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar compras',
            description: snapshot.error.toString(),
          );
        }

        final data =
            snapshot.data ??
            const _PurchasesPageData(purchases: [], items: [], isOwner: false);

        return _PurchasesContent(
          data: data,
          onCreatePurchase: _openCreatePurchaseDialog,
          onEditHeader: _openEditHeaderDialog,
          onVoidPurchase: _voidPurchase,
        );
      },
    );
  }
}

class _PurchasesContent extends StatefulWidget {
  final _PurchasesPageData data;
  final VoidCallback onCreatePurchase;
  final void Function(PurchaseManagementItem) onEditHeader;
  final void Function(PurchaseManagementItem) onVoidPurchase;

  const _PurchasesContent({
    required this.data,
    required this.onCreatePurchase,
    required this.onEditHeader,
    required this.onVoidPurchase,
  });

  @override
  State<_PurchasesContent> createState() => _PurchasesContentState();
}

class _PurchasesContentState extends State<_PurchasesContent> {
  String _searchQuery = '';
  String _selectedMethod = 'all'; // all, cash, transfer, card, credit, voided

  List<PurchaseManagementItem> _filterPurchases(List<PurchaseManagementItem> list) {
    return list.where((p) {
      if (_selectedMethod == 'voided') {
        if (p.active) return false;
      } else if (_selectedMethod != 'all') {
        if (!p.active || p.paymentMethod != _selectedMethod) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final supplierMatch = p.supplierName.toLowerCase().contains(query);
        final invoiceMatch = (p.invoiceNumber ?? '').toLowerCase().contains(query);
        final notesMatch = (p.notes ?? '').toLowerCase().contains(query);
        if (!supplierMatch && !invoiceMatch && !notesMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final purchases = widget.data.purchases;
    final items = widget.data.items;

    final activePurchases = purchases.where((p) => p.active);
    final totalPurchases = activePurchases.length;
    final totalAmount = activePurchases.fold<num>(
      0,
      (sum, purchase) => sum + purchase.totalAmount,
    );

    final suppliers = activePurchases
        .map((purchase) => purchase.supplierName)
        .toSet()
        .length;

    final filteredPurchases = _filterPurchases(purchases);

    return AppPage(
      title: 'Compras',
      subtitle:
          'Control de compras a proveedores e insumos. Solo el propietario '
          'puede editar el encabezado o anular una compra.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.onCreatePurchase,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Registrar compra'),
          ),
        ),
        const SizedBox(height: 16),
        _PurchasesSummaryCard(
          totalPurchases: totalPurchases,
          totalAmount: totalAmount,
          suppliers: suppliers,
          itemLines: items.length,
        ),
        const SizedBox(height: 16),

        // Buscador y Chips de Medios de Pago
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
                    hintText: 'Buscar por proveedor, número de factura o notas...',
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
                      _buildChip('all', 'Todas (${activePurchases.length})'),
                      const SizedBox(width: 8),
                      _buildChip('cash', '💵 Efectivo'),
                      const SizedBox(width: 8),
                      _buildChip('transfer', '📱 Transferencia'),
                      const SizedBox(width: 8),
                      _buildChip('card', '💳 Tarjeta'),
                      const SizedBox(width: 8),
                      _buildChip('credit', '📄 Crédito'),
                      const SizedBox(width: 8),
                      _buildChip('voided', '🚫 Anuladas (${purchases.where((p) => !p.active).length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const SectionTitle('Compras registradas'),
        const SizedBox(height: 12),
        _PurchasesTable(
          purchases: filteredPurchases,
          isOwner: widget.data.isOwner,
          onEditHeader: widget.onEditHeader,
          onVoidPurchase: widget.onVoidPurchase,
        ),
        const SizedBox(height: 24),
        const SectionTitle('Detalle de productos comprados'),
        const SizedBox(height: 12),
        _PurchaseItemsTable(items: items),
      ],
    );
  }

  Widget _buildChip(String key, String label) {
    final isSelected = _selectedMethod == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedMethod = key);
        }
      },
    );
  }
}

class _PurchasesSummaryCard extends StatelessWidget {
  final int totalPurchases;
  final num totalAmount;
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
          description: 'Facturas activas',
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          title: 'Total comprado',
          value: '\$${totalAmount.toStringAsFixed(0)}',
          description: 'Valor total activo',
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
  final List<PurchaseManagementItem> purchases;
  final bool isOwner;
  final void Function(PurchaseManagementItem) onEditHeader;
  final void Function(PurchaseManagementItem) onVoidPurchase;

  const _PurchasesTable({
    required this.purchases,
    required this.isOwner,
    required this.onEditHeader,
    required this.onVoidPurchase,
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
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Fecha')),
              const DataColumn(label: Text('Proveedor')),
              const DataColumn(label: Text('Factura')),
              const DataColumn(label: Text('Total')),
              const DataColumn(label: Text('Pago')),
              const DataColumn(label: Text('Notas')),
              const DataColumn(label: Text('Estado')),
              if (isOwner) const DataColumn(label: Text('Acciones')),
            ],
            rows: [
              for (final purchase in purchases)
                DataRow(
                  cells: [
                    DataCell(Text(purchase.purchaseDateText)),
                    DataCell(
                      Text(
                        purchase.supplierName,
                        style: TextStyle(
                          color: purchase.active
                              ? null
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    DataCell(Text(purchase.invoiceText)),
                    DataCell(Text(purchase.formattedTotalAmount)),
                    DataCell(Text(purchase.paymentMethodText)),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          purchase.notesText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      purchase.active
                          ? const Text('Activa')
                          : const Text(
                              'Anulada',
                              style: TextStyle(color: AppColors.danger),
                            ),
                    ),
                    if (isOwner)
                      DataCell(
                        purchase.active
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar encabezado',
                                    onPressed: () => onEditHeader(purchase),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Anular',
                                    onPressed: () => onVoidPurchase(purchase),
                                    icon: const Icon(
                                      Icons.block_outlined,
                                      size: 20,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
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

  const _PurchaseItemsTable({required this.items});

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
      color: AppColors.surface,
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
  final List<PurchaseManagementItem> purchases;
  final List<PurchaseItemSummary> items;
  final bool isOwner;

  const _PurchasesPageData({
    required this.purchases,
    required this.items,
    required this.isOwner,
  });
}

class _PurchaseHeaderDialog extends StatefulWidget {
  const _PurchaseHeaderDialog({
    required this.purchasesService,
    required this.existing,
  });

  final PurchasesService purchasesService;
  final PurchaseManagementItem existing;

  @override
  State<_PurchaseHeaderDialog> createState() => _PurchaseHeaderDialogState();
}

class _PurchaseHeaderDialogState extends State<_PurchaseHeaderDialog> {
  late final supplierController = TextEditingController(
    text: widget.existing.supplierName,
  );
  late final invoiceController = TextEditingController(
    text: widget.existing.invoiceNumber ?? '',
  );
  late final notesController = TextEditingController(
    text: widget.existing.notes ?? '',
  );
  late DateTime purchaseDate =
      DateTime.tryParse(widget.existing.purchaseDate) ?? DateTime.now();
  late String paymentMethod = widget.existing.paymentMethod;
  bool isSaving = false;
  String? errorMessage;

  @override
  void dispose() {
    supplierController.dispose();
    invoiceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => purchaseDate = picked);
    }
  }

  Future<void> _save() async {
    final supplier = supplierController.text.trim();

    if (supplier.isEmpty) {
      setState(() => errorMessage = 'El proveedor es obligatorio.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.purchasesService.updatePurchaseHeader(
        purchaseId: widget.existing.id,
        supplierName: supplier,
        purchaseDate: purchaseDate,
        invoiceNumber: invoiceController.text.trim().isEmpty
            ? null
            : invoiceController.text.trim(),
        paymentMethod: paymentMethod,
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
      title: const Text('Editar encabezado de compra'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(labelText: 'Proveedor'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(
                  '${purchaseDate.day.toString().padLeft(2, '0')}/'
                  '${purchaseDate.month.toString().padLeft(2, '0')}/'
                  '${purchaseDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: invoiceController,
              decoration: const InputDecoration(
                labelText: 'Número de factura (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Forma de pago'),
              items: kPaymentMethods
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(paymentMethodLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
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

class _PurchaseItemForm {
  _PurchaseItemForm({this.productId})
    : quantityController = TextEditingController(),
      unitCostController = TextEditingController();

  String? productId;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
  }
}

class _PurchaseFormDialog extends StatefulWidget {
  const _PurchaseFormDialog({
    required this.purchasesService,
    required this.products,
  });

  final PurchasesService purchasesService;
  final List<ProductManagementItem> products;

  @override
  State<_PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<_PurchaseFormDialog> {
  final supplierController = TextEditingController();
  final invoiceController = TextEditingController();
  final notesController = TextEditingController();
  DateTime purchaseDate = DateTime.now();
  String paymentMethod = 'cash';
  final List<_PurchaseItemForm> lineItems = [
    _PurchaseItemForm(),
  ];
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    lineItems.first.productId = widget.products.first.id;
  }

  @override
  void dispose() {
    supplierController.dispose();
    invoiceController.dispose();
    notesController.dispose();
    for (final item in lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      lineItems.add(
        _PurchaseItemForm(productId: widget.products.first.id),
      );
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      lineItems[index].dispose();
      lineItems.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => purchaseDate = picked);
    }
  }

  Future<void> _save() async {
    final supplier = supplierController.text.trim();

    if (supplier.isEmpty) {
      setState(() => errorMessage = 'El proveedor es obligatorio.');
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (final line in lineItems) {
      final quantity = num.tryParse(line.quantityController.text.trim());
      final unitCost = num.tryParse(line.unitCostController.text.trim());

      if (line.productId == null) {
        setState(() => errorMessage = 'Selecciona un producto en cada línea.');
        return;
      }
      if (quantity == null || quantity <= 0) {
        setState(
          () => errorMessage = 'La cantidad debe ser un número mayor a cero.',
        );
        return;
      }
      if (unitCost == null || unitCost < 0) {
        setState(
          () => errorMessage = 'El costo unitario debe ser un número válido.',
        );
        return;
      }

      items.add({
        'product_id': line.productId,
        'quantity': quantity,
        'unit_cost': unitCost,
      });
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.purchasesService.createPurchase(
        supplierName: supplier,
        items: items,
        purchaseDate: purchaseDate,
        invoiceNumber: invoiceController.text.trim().isEmpty
            ? null
            : invoiceController.text.trim(),
        paymentMethod: paymentMethod,
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

  num get _estimatedTotal {
    num total = 0;
    for (final line in lineItems) {
      final quantity = num.tryParse(line.quantityController.text.trim()) ?? 0;
      final unitCost = num.tryParse(line.unitCostController.text.trim()) ?? 0;
      total += quantity * unitCost;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar compra'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(labelText: 'Proveedor'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha'),
                  child: Text(
                    '${purchaseDate.day.toString().padLeft(2, '0')}/'
                    '${purchaseDate.month.toString().padLeft(2, '0')}/'
                    '${purchaseDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: invoiceController,
                decoration: const InputDecoration(
                  labelText: 'Número de factura (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Forma de pago'),
                items: kPaymentMethods
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(paymentMethodLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => paymentMethod = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Productos comprados',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < lineItems.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: lineItems[i].productId,
                          decoration: const InputDecoration(
                            labelText: 'Producto',
                          ),
                          items: widget.products
                              .map(
                                (product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text(
                                    product.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => lineItems[i].productId = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: lineItems[i].quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: lineItems[i].unitCostController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Costo unit.',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (lineItems.length > 1)
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => _removeLineItem(i),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar producto'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total estimado: \$${_estimatedTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
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
