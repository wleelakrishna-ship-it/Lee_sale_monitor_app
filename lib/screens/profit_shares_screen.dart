import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../utils/formatters.dart';
import '../widgets/saving_button.dart';
import '../widgets/summary_card.dart';
import 'profit_share_detail_screen.dart';

class ProfitSharesScreen extends StatefulWidget {
  const ProfitSharesScreen({super.key});

  @override
  State<ProfitSharesScreen> createState() => _ProfitSharesScreenState();
}

class _ProfitSharesScreenState extends State<ProfitSharesScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TextEditingController? _investorFieldController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadOverview();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addProfitShare(FinanceProvider provider) async {
    final investorName = _investorFieldController?.text.trim() ?? '';
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (investorName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_investor_name'))));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_amount_greater_zero'))));
      return;
    }
    final note = _noteController.text.trim();
    try {
      await provider.addProfitShare(
        investorName: investorName,
        amount: amount,
        note: note.isEmpty ? null : note,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
      return;
    }
    if (!mounted) return;
    _investorFieldController?.clear();
    _amountController.clear();
    _noteController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, 'profit_share_added'))));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'profit_shares_title'))),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.loadOverview,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Builder(builder: (context) {
                    final status =
                        netStatus(provider.totalInvestedAllTime, provider.totalSharedAllTime);
                    return Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: tr(context, 'total_shared_card'),
                            value: formatCurrency(provider.totalSharedAllTime),
                            icon: Icons.volunteer_activism,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SummaryCard(
                            title: status.isProfit
                                ? tr(context, 'net_profit_card')
                                : tr(context, 'net_outstanding_card'),
                            value: status.isProfit
                                ? '+${formatCurrency(status.amount)}'
                                : formatCurrency(status.amount),
                            icon: Icons.account_balance_wallet_outlined,
                            color: status.isProfit ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  Text(tr(context, 'add_profit_share_label'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (textValue) {
                      if (textValue.text.isEmpty) return const Iterable<String>.empty();
                      return provider.investorNames.where(
                        (name) => name.toLowerCase().contains(textValue.text.toLowerCase()),
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                      _investorFieldController = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: tr(context, 'investor_name_label'),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr(context, 'amount_shared_label'),
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: tr(context, 'note_optional_label'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SavingButton(
                    label: tr(context, 'add_profit_share_button'),
                    icon: Icons.add,
                    onPressed: () => _addProfitShare(provider),
                  ),
                  const Divider(height: 32),
                  Text(tr(context, 'per_investor_label'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (provider.investorTotals.isEmpty)
                    Text(tr(context, 'no_investors_yet'))
                  else
                    ...provider.investorTotals.map((investor) => _InvestorTotalRow(investor: investor)),
                ],
              ),
            ),
    );
  }
}

class _InvestorTotalRow extends StatelessWidget {
  final InvestorTotal investor;

  const _InvestorTotalRow({required this.investor});

  @override
  Widget build(BuildContext context) {
    final status = netStatus(investor.invested, investor.shared);
    final netColor = status.isProfit ? Colors.green.shade700 : Colors.red.shade700;
    final displayValue =
        status.isProfit ? '+${formatCurrency(status.amount)}' : formatCurrency(status.amount);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(investor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${tr(context, 'invested_word')} ${formatCurrency(investor.invested)} • '
          '${tr(context, 'shared_word')} ${formatCurrency(investor.shared)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(displayValue, style: TextStyle(color: netColor, fontWeight: FontWeight.bold)),
                Text(
                  tr(context, status.isProfit ? 'net_status_profit' : 'net_status_outstanding'),
                  style: TextStyle(color: netColor, fontSize: 11),
                ),
              ],
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfitShareDetailScreen(investorName: investor.name),
          ),
        ),
      ),
    );
  }
}
