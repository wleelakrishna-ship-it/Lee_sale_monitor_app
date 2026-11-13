import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';

class ProfitShareDetailScreen extends StatefulWidget {
  final String investorName;

  const ProfitShareDetailScreen({super.key, required this.investorName});

  @override
  State<ProfitShareDetailScreen> createState() => _ProfitShareDetailScreenState();
}

class _ProfitShareDetailScreenState extends State<ProfitShareDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadProfitShareRecords(widget.investorName);
    });
  }

  Future<void> _editProfitShare(ProfitShare share) async {
    final amountController = TextEditingController(text: share.amount.toString());
    final noteController = TextEditingController(text: share.note ?? '');
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
              await provider.updateProfitShareRecord(
                ProfitShare(
                  id: share.id,
                  investorName: share.investorName,
                  amount: amount,
                  date: share.date,
                  note: note.isEmpty ? null : note,
                  createdAt: share.createdAt,
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
            title: Text(tr(context, 'edit_profit_share_title')),
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
                    decoration: InputDecoration(labelText: tr(context, 'amount_shared_label')),
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
          .showSnackBar(SnackBar(content: Text(tr(context, 'profit_share_updated'))));
    }
  }

  Future<void> _deleteProfitShare(ProfitShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'delete_profit_share_title')),
        content: Text(tr(context, 'delete_profit_share_body', {
          'amount': formatCurrency(share.amount),
          'date': formatDisplayDate(dbDateFormat.parse(share.date)),
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
        await context
            .read<FinanceProvider>()
            .deleteProfitShareRecord(share.id!, share.investorName);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'profit_share_deleted'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final records = provider.profitShareRecords;
    InvestorTotal? total;
    for (final t in provider.investorTotals) {
      if (t.name == widget.investorName) total = t;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.investorName)),
      body: provider.profitShareRecordsLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<FinanceProvider>().loadProfitShareRecords(widget.investorName),
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
                  Text(tr(context, 'profit_share_records_label'),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          Text(tr(context, 'no_profit_share_records'), textAlign: TextAlign.center),
                    )
                  else
                    ...records.map(
                      (share) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            formatCurrency(share.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            share.note == null || share.note!.isEmpty
                                ? formatDisplayDate(dbDateFormat.parse(share.date))
                                : '${formatDisplayDate(dbDateFormat.parse(share.date))} • ${share.note}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editProfitShare(share),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteProfitShare(share),
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
