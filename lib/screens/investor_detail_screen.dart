import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';

class InvestorDetailScreen extends StatefulWidget {
  final String investorName;

  const InvestorDetailScreen({super.key, required this.investorName});

  @override
  State<InvestorDetailScreen> createState() => _InvestorDetailScreenState();
}

class _InvestorDetailScreenState extends State<InvestorDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadInvestorRecords(widget.investorName);
    });
  }

  Future<void> _editInvestment(Investor investor) async {
    final amountController = TextEditingController(text: investor.amount.toString());
    final noteController = TextEditingController(text: investor.note ?? '');
    final formKey = GlobalKey<FormState>();
    final provider = context.read<FinanceProvider>();
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
            final amount = double.parse(amountController.text);
            final note = noteController.text.trim();
            try {
              await provider.updateInvestorRecord(
                Investor(
                  id: investor.id,
                  name: investor.name,
                  amount: amount,
                  date: investor.date,
                  note: note.isEmpty ? null : note,
                  createdAt: investor.createdAt,
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
            title: Text(tr(context, 'edit_investment_title')),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    autofocus: true,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'amount_invested_label')),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return tr(context, 'enter_amount_greater_zero');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    enabled: !submitting,
                    decoration: InputDecoration(labelText: tr(context, 'note_optional_label')),
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

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'investment_updated'))));
    }
  }

  Future<void> _deleteInvestment(Investor investor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'delete_investment_title')),
        content: Text(tr(context, 'delete_investment_body', {
          'amount': formatCurrency(investor.amount),
          'date': formatDisplayDate(dbDateFormat.parse(investor.date)),
        })),
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
        await context.read<FinanceProvider>().deleteInvestorRecord(investor.id!, investor.name);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'investment_deleted'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final records = provider.investorRecords;
    InvestorTotal? total;
    for (final t in provider.investorTotals) {
      if (t.name == widget.investorName) total = t;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.investorName)),
      body: provider.investorRecordsLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<FinanceProvider>().loadInvestorRecords(widget.investorName),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: tr(context, 'invested_word'),
                          value: formatCurrency(total?.invested ?? 0),
                          icon: Icons.trending_up,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryCard(
                          title: tr(context, 'shared_word'),
                          value: formatCurrency(total?.shared ?? 0),
                          icon: Icons.volunteer_activism,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(tr(context, 'investment_records_label'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr(context, 'no_investment_records'), textAlign: TextAlign.center),
                    )
                  else
                    ...records.map(
                      (investor) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            formatCurrency(investor.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            investor.note == null || investor.note!.isEmpty
                                ? formatDisplayDate(dbDateFormat.parse(investor.date))
                                : '${formatDisplayDate(dbDateFormat.parse(investor.date))} • ${investor.note}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editInvestment(investor),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteInvestment(investor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
