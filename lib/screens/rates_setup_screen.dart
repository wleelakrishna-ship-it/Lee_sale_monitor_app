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
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                decoration: InputDecoration(labelText: tr(context, 'fish_category_label')),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? tr(context, 'enter_category_name') : null,
              ),
              TextFormField(
                controller: rateController,
                decoration: InputDecoration(labelText: tr(context, 'rate_per_kg_label')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return tr(context, 'enter_valid_rate');
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(tr(context, 'save')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final provider = context.read<RatesProvider>();
      final category = nameController.text.trim();
      final rate = double.parse(rateController.text);
      if (existing == null) {
        await provider.addCategory(category, rate);
      } else {
        await provider.updateCategory(existing.copyWith(category: category, ratePerKg: rate));
      }
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
                        subtitle:
                            Text('${formatCurrency(rate.ratePerKg)} ${tr(context, 'rate_per_kg_suffix')}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showCategoryDialog(existing: rate),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => context.read<RatesProvider>().deleteCategory(rate.id!),
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
