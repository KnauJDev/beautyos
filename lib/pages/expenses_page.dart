import 'package:flutter/material.dart';

import '../models/expense_summary.dart';
import '../services/expenses_service.dart';
import '../widgets/app_widgets.dart';

class GastosPage extends StatefulWidget {
  const GastosPage({super.key});

  @override
  State<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends State<GastosPage> {
  final ExpensesService _expensesService = const ExpensesService();

  late Future<List<ExpenseSummary>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _expensesFuture = _expensesService.getExpensesSummary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExpenseSummary>>(
      future: _expensesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar gastos',
            description: snapshot.error.toString(),
          );
        }

        final expenses = snapshot.data ?? [];

        return _ExpensesContent(expenses: expenses);
      },
    );
  }
}

class _ExpensesContent extends StatelessWidget {
  final List<ExpenseSummary> expenses;

  const _ExpensesContent({
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final totalExpenses = expenses.length;
    final totalAmount = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final categories = expenses
        .map((expense) => expense.category)
        .toSet()
        .length;

    final paymentMethods = expenses
        .map((expense) => expense.paymentMethod)
        .toSet()
        .length;

    return AppPage(
      title: 'Gastos',
      subtitle: 'Control de gastos operativos del negocio.',
      children: [
        const InfoPanel(
          icon: Icons.payments_outlined,
          title: 'Gastos del negocio',
          description:
              'Aqui se registran los gastos que afectan la utilidad real del centro de belleza.',
        ),
        const SizedBox(height: 16),
        _ExpensesSummaryCard(
          totalExpenses: totalExpenses,
          totalAmount: totalAmount,
          categories: categories,
          paymentMethods: paymentMethods,
        ),
        const SizedBox(height: 16),
        const SectionTitle('Gastos registrados'),
        const SizedBox(height: 12),
        _ExpensesTable(expenses: expenses),
      ],
    );
  }
}

class _ExpensesSummaryCard extends StatelessWidget {
  final int totalExpenses;
  final double totalAmount;
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
          description: 'Registros cargados',
          icon: Icons.receipt_long_outlined,
        ),
        MetricCard(
          title: 'Total gastos',
          value: '\$${totalAmount.toStringAsFixed(0)}',
          description: 'Valor total registrado',
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
  final List<ExpenseSummary> expenses;

  const _ExpensesTable({
    required this.expenses,
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('Categoria')),
              DataColumn(label: Text('Descripcion')),
              DataColumn(label: Text('Valor')),
              DataColumn(label: Text('Pago')),
              DataColumn(label: Text('Notas')),
            ],
            rows: [
              for (final expense in expenses)
                DataRow(
                  cells: [
                    DataCell(Text(expense.expenseDate)),
                    DataCell(Text(expense.category)),
                    DataCell(Text(expense.description)),
                    DataCell(Text(expense.formattedAmount)),
                    DataCell(Text(expense.paymentMethodText)),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: Text(
                          expense.notesText,
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
