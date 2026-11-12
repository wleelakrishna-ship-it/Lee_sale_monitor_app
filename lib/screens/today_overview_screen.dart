import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/buyer_summary.dart';
import '../providers/sales_provider.dart';
import '../utils/formatters.dart';
import '../widgets/buyer_row.dart';
import 'buyer_day_detail_screen.dart';

class TodayOverviewScreen extends StatefulWidget {
  const TodayOverviewScreen({super.key});

  @override
  State<TodayOverviewScreen> createState() => _TodayOverviewScreenState();
}

class _TodayOverviewScreenState extends State<TodayOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadTodayOverview();
    });
  }

  Future<void> _recordPayment(BuyerSummary summary) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final salesProvider = context.read<SalesProvider>();
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
              await salesProvider.addPaymentForBuyer(summary.buyerName, amount);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setDialogState(() {
                submitting = false;
                errorText = tr(context, 'local_save_failed_message');
              });
            }
          }

          return AlertDialog(
            title: Text(tr(context, 'add_payment_dialog_title', {'buyer': summary.buyerName})),
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
                    decoration: InputDecoration(
                      labelText: tr(context, 'amount_given_field'),
                      helperText: tr(
                          context, 'current_balance_helper', {'balance': formatCurrency(summary.balance)}),
                    ),
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
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr(context, 'save')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = context.watch<SalesProvider>();
    final summaries = salesProvider.todaySummaries;
    final totals = salesProvider.dayTotals;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'today_overview_title'))),
      body: salesProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<SalesProvider>().loadTodayOverview(),
                    child: summaries.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(tr(context, 'no_sales_today'), textAlign: TextAlign.center),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: summaries.length,
                            itemBuilder: (context, index) {
                              final summary = summaries[index];
                              return BuyerRow(
                                summary: summary,
                                onTap: summary.balance > 0 ? () => _recordPayment(summary) : null,
                                onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BuyerDayDetailScreen(buyerName: summary.buyerName),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: const Border(top: BorderSide(color: Colors.black12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _FooterStat(
                              label: tr(context, 'total_kg_footer'), value: formatKg(totals.totalKg)),
                          _FooterStat(
                            label: tr(context, 'total_amount_footer'),
                            value: formatCurrency(totals.totalAmount),
                          ),
                        ],
                      ),
                      if (totals.totalCommission > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FooterStat(
                              label: tr(context, 'commission_footer'),
                              value: formatCurrency(totals.totalCommission),
                            ),
                            _FooterStat(
                              label: tr(context, 'net_amount_footer'),
                              value: formatCurrency(totals.totalAmount - totals.totalCommission),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  final String label;
  final String value;

  const _FooterStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
