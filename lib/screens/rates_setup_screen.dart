import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category_rate.dart';
import '../providers/rates_provider.dart';
import '../utils/formatters.dart';

class RatesSetupScreen extends StatefulWidget {
  const RatesSetupScreen({super.key});

  @override
  State<RatesSetupScreen> createState() => _RatesSetupScreenState();
}

class _RatesSetupScreenState extends State<RatesSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatesProvider>().loadTodayRates();
    });
  }

  Future<void> _showCategoryDialog({CategoryRate? existing}) async {
    final nameController = TextEditingController(text: existing?.category ?? '');
    final rateController = TextEditingController(
      text: existing != null ? existing.ratePerKg.toString() : '',
    );
    final commissionController = TextEditingController(
      text: existing != null && existing.commissionPerKg > 0
          ? existing.commissionPerKg.toString()
          : '',
    );
    final formKey = GlobalKey<FormState>();
    final provider = context.read<RatesProvider>();
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
            final category = nameController.text.trim();
            final rate = double.parse(rateController.text);
            final commission = double.tryParse(commissionController.text) ?? 0.0;
            try {
              if (existing == null) {
                await provider.addCategory(category, rate, commission);
              } else {
                await provider.updateCategory(
                  existing.copyWith(category: category, ratePerKg: rate, commissionPerKg: commission),
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              setDialogState(() {
                submitting = false;
                errorText = tr(context, 'local_save_failed_message');
              });
            }
          }

          return AlertDialog(
            title: Text(existing == null
                ? tr(context, 'add_category_title')
                : tr(context, 'edit_category_title')),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    enabled: !submitting,
                    decoration: InputDecoration(labelText: tr(context, 'fish_category_label')),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? tr(context, 'enter_category_name')
                        : null,
                  ),
                  TextFormField(
                    controller: rateController,
                    enabled: !submitting,
                    decoration: InputDecoration(labelText: tr(context, 'rate_per_kg_label')),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return tr(context, 'enter_valid_rate');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commissionController,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: tr(context, 'commission_per_kg_label'),
                      helperText: tr(context, 'commission_per_kg_helper'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0) return tr(context, 'enter_valid_commission');
                      final rate = double.tryParse(rateController.text);
                      if (rate != null && parsed > rate) {
                        return tr(context, 'commission_exceeds_rate');
                      }
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

  Future<void> _deleteCategory(String id) async {
    try {
      await context.read<RatesProvider>().deleteCategory(id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RatesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'rates_setup_title')),
        actions: [
          IconButton(
            tooltip: tr(context, 'copy_yesterday_tooltip'),
            icon: const Icon(Icons.content_copy),
            onPressed: () async {
              final copied = await context.read<RatesProvider>().copyYesterdaysRates();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    copied ? tr(context, 'copied_yesterday_rates') : tr(context, 'no_previous_rates'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.todayRates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(context, 'no_categories_today'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.todayRates.length,
                  itemBuilder: (context, index) {
                    final rate = provider.todayRates[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(rate.category),
                        subtitle: Text(
                          rate.commissionPerKg > 0
                              ? '${formatCurrency(rate.ratePerKg)} ${tr(context, 'rate_per_kg_suffix')} • '
                                  '${tr(context, 'commission_word')} ${formatCurrency(rate.commissionPerKg)} • '
                                  '${tr(context, 'net_word')} ${formatCurrency(rate.netPerKg)}'
                              : '${formatCurrency(rate.ratePerKg)} ${tr(context, 'rate_per_kg_suffix')}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showCategoryDialog(existing: rate),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteCategory(rate.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
