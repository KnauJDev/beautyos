import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/expense_management_item.dart';
import '../services/expenses_service.dart';
import '../services/my_profile_service.dart';
import '../widgets/app_widgets.dart';

const List<String> kExpensePaymentMethods = [
  'cash',
  'transfer',
  'card',
  'credit',
  'other',
];

String expensePaymentMethodLabel(String value) {
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

class GastosPage extends StatefulWidget {
  const GastosPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends State<GastosPage> {
  late final ExpensesService _expensesService;
  final MyProfileService _myProfileService = const MyProfileService();

  late Future<_ExpensesPageData> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _expensesService = ExpensesService(branchId: widget.branchId);
    _expensesFuture = _loadExpensesData();
  }

  Future<_ExpensesPageData> _loadExpensesData() async {
    final expenses = await _expensesService.getExpensesForManagement();
    final profile = await _myProfileService.getMyProfile();

    return _ExpensesPageData(
      expenses: expenses,
      isOwner: profile?.role == 'owner',
    );
  }

  void _reload() {
    setState(() {
      _expensesFuture = _loadExpensesData();
    });
  }

  Future<void> _openCreateDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        expensesService: _expensesService,
        existing: null,
      ),
    );

    if (saved == true) _reload();
  }

  Future<void> _openEditDialog(ExpenseManagementItem expense) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        expensesService: _expensesService,
        existing: expense,
      ),
    );

    if (saved == true) _reload();
  }

  Future<void> _toggleActive(ExpenseManagementItem expense) async {
    try {
      await _expensesService.setExpenseActive(
        expenseId: expense.id,
        active: !expense.active,
      );
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
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExpensesPageData>(
      future: _expensesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar gastos',
            description: snapshot.error.toString(),
          );
        }

        final data =
            snapshot.data ?? const _ExpensesPageData(expenses: [], isOwner: false);

        return _ExpensesContent(
          data: data,
          onCreate: _openCreateDialog,
          onEdit: _openEditDialog,
          onToggleActive: _toggleActive,
        );
      },
    );
  }
}

class _ExpensesContent extends StatefulWidget {
  final _ExpensesPageData data;
  final VoidCallback onCreate;
  final void Function(ExpenseManagementItem) onEdit;
  final void Function(ExpenseManagementItem) onToggleActive;

  const _ExpensesContent({
    required this.data,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  State<_ExpensesContent> createState() => _ExpensesContentState();
}

class _ExpensesContentState extends State<_ExpensesContent> {
  String _searchQuery = '';
  String _selectedMethod = 'all'; // all, cash, transfer, card, credit, voided

  List<ExpenseManagementItem> _filterExpenses(List<ExpenseManagementItem> list) {
    return list.where((e) {
      if (_selectedMethod == 'voided') {
        if (e.active) return false;
      } else if (_selectedMethod != 'all') {
        if (!e.active || e.paymentMethod != _selectedMethod) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final descMatch = e.description.toLowerCase().contains(query);
        final catMatch = e.category.toLowerCase().contains(query);
        final notesMatch = (e.notes ?? '').toLowerCase().contains(query);
        if (!descMatch && !catMatch && !notesMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.data.expenses;
    final activeExpenses = expenses.where((e) => e.active);

    final totalExpenses = activeExpenses.length;
    final totalAmount = activeExpenses.fold<num>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final categories = activeExpenses.map((e) => e.category).toSet().length;
    final paymentMethods = activeExpenses
        .map((e) => e.paymentMethod)
        .toSet()
        .length;

    final filteredExpenses = _filterExpenses(expenses);

    return AppPage(
      title: 'Gastos',
      subtitle: 'Control de gastos operativos del negocio.',
      children: [
        const InfoPanel(
          icon: Icons.payments_outlined,
          title: 'Gastos del negocio',
          description:
              'Registra los gastos que afectan la utilidad real del centro. Solo el propietario puede editar o anular un gasto ya guardado.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.onCreate,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Registrar gasto'),
          ),
        ),
        const SizedBox(height: 16),
        _ExpensesSummaryCard(
          totalExpenses: totalExpenses,
          totalAmount: totalAmount,
          categories: categories,
          paymentMethods: paymentMethods,
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
                    hintText: 'Buscar por descripción, categoría o notas...',
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
                      _buildChip('all', 'Todos (${activeExpenses.length})'),
                      const SizedBox(width: 8),
                      _buildChip('cash', '💵 Efectivo'),
                      const SizedBox(width: 8),
                      _buildChip('transfer', '📱 Transferencia'),
                      const SizedBox(width: 8),
                      _buildChip('card', '💳 Tarjeta'),
                      const SizedBox(width: 8),
                      _buildChip('credit', '📄 Crédito'),
                      const SizedBox(width: 8),
                      _buildChip('voided', '🚫 Anulados (${expenses.where((e) => !e.active).length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const SectionTitle('Gastos registrados'),
        const SizedBox(height: 12),
        _ExpensesTable(
          expenses: filteredExpenses,
          isOwner: widget.data.isOwner,
          onEdit: widget.onEdit,
          onToggleActive: widget.onToggleActive,
        ),
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

class _ExpensesSummaryCard extends StatelessWidget {
  final int totalExpenses;
  final num totalAmount;
  final int categories;
  final int paymentMethods;

  const _ExpensesSummaryCard({
    required this.totalExpenses,
    required this.totalAmount,
    required this.categories,
    required this.paymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        MetricCard(
          title: 'Gastos',
          value: '$totalExpenses',
          description: 'Registros activos',
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          title: 'Total gastos',
          value: '\$${totalAmount.toStringAsFixed(0)}',
          description: 'Valor total activo',
          icon: Icons.attach_money,
        ),
        MetricCard(
          title: 'Categorias',
          value: '$categories',
          description: 'Tipos de gasto',
          icon: Icons.category_outlined,
        ),
        MetricCard(
          title: 'Formas de pago',
          value: '$paymentMethods',
          description: 'Metodos utilizados',
          icon: Icons.credit_card_outlined,
        ),
      ],
    );
  }
}

class _ExpensesTable extends StatelessWidget {
  final List<ExpenseManagementItem> expenses;
  final bool isOwner;
  final void Function(ExpenseManagementItem) onEdit;
  final void Function(ExpenseManagementItem) onToggleActive;

  const _ExpensesTable({
    required this.expenses,
    required this.isOwner,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const InfoPanel(
        icon: Icons.info_outline,
        title: 'Sin gastos registrados',
        description: 'Todavia no hay gastos cargados en el sistema.',
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
              const DataColumn(label: Text('Categoria')),
              const DataColumn(label: Text('Descripcion')),
              const DataColumn(label: Text('Valor')),
              const DataColumn(label: Text('Pago')),
              const DataColumn(label: Text('Notas')),
              const DataColumn(label: Text('Estado')),
              if (isOwner) const DataColumn(label: Text('Acciones')),
            ],
            rows: [
              for (final expense in expenses)
                DataRow(
                  cells: [
                    DataCell(Text(expense.expenseDateText)),
                    DataCell(Text(expense.category)),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          expense.description,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: expense.active
                                ? null
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(expense.formattedAmount)),
                    DataCell(Text(expense.paymentMethodText)),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          expense.notesText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      expense.active
                          ? const Text('Activo')
                          : const Text(
                              'Anulado',
                              style: TextStyle(color: AppColors.danger),
                            ),
                    ),
                    if (isOwner)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => onEdit(expense),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: expense.active
                                  ? 'Anular'
                                  : 'Reactivar',
                              onPressed: () => onToggleActive(expense),
                              icon: Icon(
                                expense.active
                                    ? Icons.block_outlined
                                    : Icons.play_circle_outline,
                                size: 20,
                                color: expense.active
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            ),
                          ],
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

class _ExpensesPageData {
  final List<ExpenseManagementItem> expenses;
  final bool isOwner;

  const _ExpensesPageData({required this.expenses, required this.isOwner});
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.expensesService,
    required this.existing,
  });

  final ExpensesService expensesService;
  final ExpenseManagementItem? existing;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  late final categoryController = TextEditingController(
    text: widget.existing?.category ?? '',
  );
  late final descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final amountController = TextEditingController(
    text: widget.existing?.amount.toString() ?? '',
  );
  late final notesController = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  late DateTime expenseDate = widget.existing != null
      ? (DateTime.tryParse(widget.existing!.expenseDate) ?? DateTime.now())
      : DateTime.now();
  late String paymentMethod = widget.existing?.paymentMethod ?? 'cash';
  bool isSaving = false;
  String? errorMessage;

  bool get isEditing => widget.existing != null;

  @override
  void dispose() {
    categoryController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => expenseDate = picked);
    }
  }

  Future<void> _save() async {
    final category = categoryController.text.trim();
    final description = descriptionController.text.trim();
    final amount = num.tryParse(amountController.text.trim());

    if (category.isEmpty) {
      setState(() => errorMessage = 'La categoría es obligatoria.');
      return;
    }
    if (description.isEmpty) {
      setState(() => errorMessage = 'La descripción es obligatoria.');
      return;
    }
    if (amount == null || amount < 0) {
      setState(() => errorMessage = 'El valor debe ser un número válido.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      if (isEditing) {
        await widget.expensesService.updateExpense(
          expenseId: widget.existing!.id,
          category: category,
          description: description,
          amount: amount,
          expenseDate: expenseDate,
          paymentMethod: paymentMethod,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
      } else {
        await widget.expensesService.createExpense(
          category: category,
          description: description,
          amount: amount,
          expenseDate: expenseDate,
          paymentMethod: paymentMethod,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
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
      title: Text(isEditing ? 'Editar gasto' : 'Registrar gasto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor (COP)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha'),
                child: Text(
                  '${expenseDate.day.toString().padLeft(2, '0')}/'
                  '${expenseDate.month.toString().padLeft(2, '0')}/'
                  '${expenseDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Forma de pago'),
              items: kExpensePaymentMethods
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(expensePaymentMethodLabel(value)),
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
