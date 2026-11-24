import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/payment.dart';
import '../providers/buyers_provider.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';

class _LedgerEntry {
  final String date;
  final String createdAt;
  final String label;
  final IconData icon;
  final double signedAmount;
  final Payment? payment;
  late double runningBalance;

  _LedgerEntry({
    required this.date,
    required this.createdAt,
    required this.label,
    required this.icon,
    required this.signedAmount,
    this.payment,
  });
}

class BuyerDetailScreen extends StatefulWidget {
  final String buyerName;

  const BuyerDetailScreen({super.key, required this.buyerName});

  @override
  State<BuyerDetailScreen> createState() => _BuyerDetailScreenState();
}

class _BuyerDetailScreenState extends State<BuyerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuyersProvider>().loadBuyerHistory(widget.buyerName);
    });
  }

  Future<void> _editPayment(Payment payment) async {
    final controller = TextEditingController(text: payment.amountGiven.toString());
    final formKey = GlobalKey<FormState>();
    final provider = context.read<BuyersProvider>();
    bool submitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() {
              submitting = true;
              errorText = null;
            });
            final amount = double.parse(controller.text);
            try {
              await provider.updatePayment(
                Payment(
                  id: payment.id,
                  date: payment.date,
                  buyerName: payment.buyerName,
                  amountGiven: amount,
                  createdAt: payment.createdAt,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setDialogState(() {
                submitting = false;
                errorText = tr(context, 'local_save_failed_message');
              });
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'edit_payment_title')),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'amount_given_field')),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return tr(context, 'enter_valid_amount');
                      return null;
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, 'save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'delete_payment_title')),
        content: Text(
            tr(context, 'delete_payment_body', {'amount': formatCurrency(payment.amountGiven)})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, 'delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<BuyersProvider>().deletePayment(payment.id!, payment.buyerName);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'payment_deleted'))));
    }
  }

  List<_LedgerEntry> _buildLedger(BuyersProvider provider) {
    final entries = <_LedgerEntry>[
      for (final sale in provider.historySales)
        _LedgerEntry(
          date: sale.date,
          createdAt: sale.createdAt,
          label: '${sale.category} • ${formatKg(sale.kilograms)} @ ${formatCurrency(sale.ratePerKg)}/kg',
          icon: Icons.shopping_basket,
          signedAmount: sale.amount,
        ),
      for (final payment in provider.historyPayments)
        _LedgerEntry(
          date: payment.date,
          createdAt: payment.createdAt,
          label: tr(context, 'payment_received_label'),
          icon: Icons.payments,
          signedAmount: -payment.amountGiven,
          payment: payment,
        ),
    ];

    entries.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.createdAt.compareTo(b.createdAt);
    });

    var runningBalance = 0.0;
    for (final entry in entries) {
      runningBalance += entry.signedAmount;
      entry.runningBalance = runningBalance;
    }

    return entries.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BuyersProvider>();
    final summary = provider.selectedBuyerSummary;
    final ledger = _buildLedger(provider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.buyerName)),
      body: provider.historyLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<BuyersProvider>().loadBuyerHistory(widget.buyerName),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 42) / 2,
                        child: SummaryCard(
                          title: tr(context, 'total_purchased_card'),
                          value: formatCurrency(summary?.totalAmount ?? 0),
                          icon: Icons.shopping_basket,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 42) / 2,
                        child: SummaryCard(
                          title: tr(context, 'total_paid_card'),
                          value: formatCurrency(summary?.totalGiven ?? 0),
                          icon: Icons.payments,
                          color: Colors.indigo,
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width - 32,
                        child: SummaryCard(
                          title: tr(context, 'outstanding_balance_card'),
                          value: formatCurrency(summary?.balance ?? 0),
                          icon: Icons.account_balance_wallet_outlined,
                          color: (summary?.balance ?? 0) > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(tr(context, 'transaction_history_label'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (ledger.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr(context, 'no_transactions_yet'), textAlign: TextAlign.center),
                    )
                  else
                    ...ledger.map((entry) {
                      final isPurchase = entry.signedAmount > 0;
                      final amountColor = isPurchase ? Colors.red.shade700 : Colors.green.shade700;
                      final sign = isPurchase ? '+' : '-';
                      final payment = entry.payment;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(entry.icon, color: amountColor),
                          title: Text(entry.label),
                          subtitle: Text(formatDisplayDate(dbDateFormat.parse(entry.date))),
                          trailing: payment != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$sign${formatCurrency(entry.signedAmount.abs())}',
                                          style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          tr(context, 'running_balance_prefix',
                                              {'amount': formatCurrency(entry.runningBalance)}),
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => _editPayment(payment),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: () => _deletePayment(payment),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$sign${formatCurrency(entry.signedAmount.abs())}',
                                      style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      tr(context, 'running_balance_prefix',
                                          {'amount': formatCurrency(entry.runningBalance)}),
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
