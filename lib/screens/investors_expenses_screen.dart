import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../providers/finance_provider.dart';
import '../utils/formatters.dart';
import '../widgets/saving_button.dart';
import '../widgets/summary_card.dart';
import 'investor_detail_screen.dart';

class InvestorsExpensesScreen extends StatefulWidget {
  const InvestorsExpensesScreen({super.key});

  @override
  State<InvestorsExpensesScreen> createState() => _InvestorsExpensesScreenState();
}

class _InvestorsExpensesScreenState extends State<InvestorsExpensesScreen> {
  final _investorNameController = TextEditingController();
  final _investorAmountController = TextEditingController();
  final _investorNoteController = TextEditingController();

  final _expenseDescriptionController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadOverview();
    });
  }

  @override
  void dispose() {
    _investorNameController.dispose();
    _investorAmountController.dispose();
    _investorNoteController.dispose();
    _expenseDescriptionController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<void> _addInvestor(FinanceProvider provider) async {
    final name = _investorNameController.text.trim();
    final amount = double.tryParse(_investorAmountController.text) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_investor_name'))));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_amount_greater_zero'))));
      return;
    }
    final note = _investorNoteController.text.trim();
    try {
      await provider.addInvestor(name: name, amount: amount, note: note.isEmpty ? null : note);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
      return;
    }
    if (!mounted) return;
    _investorNameController.clear();
    _investorAmountController.clear();
    _investorNoteController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'investment_added'))));
  }

  Future<void> _addExpense(FinanceProvider provider) async {
    final description = _expenseDescriptionController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text) ?? 0;
    if (description.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_description'))));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_amount_greater_zero'))));
      return;
    }
    try {
      await provider.addExpense(description: description, amount: amount);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
      return;
    }
    if (!mounted) return;
    _expenseDescriptionController.clear();
    _expenseAmountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'expense_added'))));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'investors_expenses_title')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr(context, 'tab_investors')),
              Tab(text: tr(context, 'tab_expenses')),
            ],
          ),
        ),
        body: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _InvestorsTab(
                    provider: provider,
                    nameController: _investorNameController,
                    amountController: _investorAmountController,
                    noteController: _investorNoteController,
                    onAdd: () => _addInvestor(provider),
                  ),
                  _ExpensesTab(
                    provider: provider,
                    descriptionController: _expenseDescriptionController,
                    amountController: _expenseAmountController,
                    onAdd: () => _addExpense(provider),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InvestorsTab extends StatelessWidget {
  final FinanceProvider provider;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final Future<void> Function() onAdd;

  const _InvestorsTab({
    required this.provider,
    required this.nameController,
    required this.amountController,
    required this.noteController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SummaryCard(
            title: tr(context, 'total_invested_card'),
            value: formatCurrency(provider.totalInvestedAllTime),
            icon: Icons.trending_up,
            color: Colors.teal,
          ),
          const SizedBox(height: 20),
          Text(tr(context, 'add_investment_label'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: tr(context, 'investor_name_label'),
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, 'amount_invested_label'),
              prefixIcon: const Icon(Icons.currency_rupee),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: InputDecoration(
              labelText: tr(context, 'note_optional_label'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SavingButton(
            label: tr(context, 'add_investment_button'),
            icon: Icons.add,
            onPressed: onAdd,
          ),
          const Divider(height: 32),
          Text(tr(context, 'investors_label'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (provider.investorTotals.isEmpty)
            Text(tr(context, 'no_investors_yet'))
          else
            ...provider.investorTotals.map(
              (investor) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(investor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatCurrency(investor.invested),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvestorDetailScreen(investorName: investor.name),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  final FinanceProvider provider;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final Future<void> Function() onAdd;

  const _ExpensesTab({
    required this.provider,
    required this.descriptionController,
    required this.amountController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SummaryCard(
            title: tr(context, 'total_expenses_card'),
            value: formatCurrency(provider.totalExpensesAllTime),
            icon: Icons.receipt_long,
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 20),
          Text(tr(context, 'add_expense_label'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: tr(context, 'amount_used_for_label'),
              prefixIcon: const Icon(Icons.description_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, 'amount_label'),
              prefixIcon: const Icon(Icons.currency_rupee),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SavingButton(
            label: tr(context, 'add_expense_button'),
            icon: Icons.add,
            onPressed: onAdd,
          ),
          const Divider(height: 32),
          Text(tr(context, 'expenses_label'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (provider.expenses.isEmpty)
            Text(tr(context, 'no_expenses_yet'))
          else
            ...provider.expenses.map(
              (expense) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(expense.description),
                  subtitle: Text(expense.date),
                  trailing: Text(
                    formatCurrency(expense.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
