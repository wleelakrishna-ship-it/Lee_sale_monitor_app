import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
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
  late double runningBalance;

  _LedgerEntry({
    required this.date,
    required this.createdAt,
    required this.label,
    required this.icon,
    required this.signedAmount,
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(entry.icon, color: amountColor),
                          title: Text(entry.label),
                          subtitle: Text(formatDisplayDate(dbDateFormat.parse(entry.date))),
                          trailing: Column(
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
