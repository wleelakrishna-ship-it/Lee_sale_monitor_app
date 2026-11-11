import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/category_rate.dart';
import '../providers/rates_provider.dart';
import '../providers/sales_provider.dart';
import '../utils/formatters.dart';
import '../widgets/category_chip.dart';
import '../widgets/saving_button.dart';

class SaleEntryScreen extends StatefulWidget {
  const SaleEntryScreen({super.key});

  @override
  State<SaleEntryScreen> createState() => _SaleEntryScreenState();
}

class _SaleEntryScreenState extends State<SaleEntryScreen> {
  final _kgController = TextEditingController();
  final _givenController = TextEditingController();
  TextEditingController? _buyerFieldController;

  CategoryRate? _selectedCategory;
  double _amountGiven = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatesProvider>().loadTodayRates();
      context.read<SalesProvider>().loadBuyerNames();
    });
    _givenController.addListener(() {
      setState(() => _amountGiven = double.tryParse(_givenController.text) ?? 0);
    });
  }

  @override
  void dispose() {
    _kgController.dispose();
    _givenController.dispose();
    super.dispose();
  }

  double get _previewAmount {
    final kg = double.tryParse(_kgController.text) ?? 0;
    final rate = _selectedCategory?.ratePerKg ?? 0;
    return kg * rate;
  }

  void _addItem(SalesProvider salesProvider) {
    final category = _selectedCategory;
    final kg = double.tryParse(_kgController.text) ?? 0;
    if (category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'select_category_first'))));
      return;
    }
    if (kg <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_kg_greater_zero'))));
      return;
    }
    salesProvider.addCartItem(
      CartItem(category: category.category, ratePerKg: category.ratePerKg, kilograms: kg),
    );
    _kgController.clear();
    setState(() => _selectedCategory = null);
  }

  Future<void> _save(SalesProvider salesProvider) async {
    final buyerName = _buyerFieldController?.text.trim() ?? '';
    if (buyerName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'enter_buyer_name'))));
      return;
    }
    if (salesProvider.cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'add_one_fish_item'))));
      return;
    }
    try {
      await salesProvider.saveSale(buyerName: buyerName, amountGiven: _amountGiven);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
      return;
    }
    if (!mounted) return;
    _buyerFieldController?.clear();
    _givenController.clear();
    setState(() => _amountGiven = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'sale_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratesProvider = context.watch<RatesProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final cartTotal = salesProvider.cartTotal;
    final balance = cartTotal - _amountGiven;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'new_sale_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Autocomplete<String>(
            optionsBuilder: (textValue) {
              if (textValue.text.isEmpty) return const Iterable<String>.empty();
              return salesProvider.buyerNames.where(
                (name) => name.toLowerCase().contains(textValue.text.toLowerCase()),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              _buyerFieldController = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: tr(context, 'buyer_name_label'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(tr(context, 'fish_category_section'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ratesProvider.todayRates.isEmpty
              ? Text(tr(context, 'no_rates_today_message'))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ratesProvider.todayRates
                      .map((rate) => CategoryChip(
                            rate: rate,
                            selected: _selectedCategory?.id == rate.id,
                            onSelected: (_) => setState(() => _selectedCategory = rate),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _kgController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr(context, 'kilograms_label'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${tr(context, 'amount_preview_prefix')} ${formatCurrency(_previewAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _addItem(salesProvider),
            icon: const Icon(Icons.add),
            label: Text(tr(context, 'add_item_button')),
          ),
          const Divider(height: 32),
          Text(tr(context, 'cart_section'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (salesProvider.cart.isEmpty)
            Text(tr(context, 'no_items_added'))
          else
            ...salesProvider.cart.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.category} — ${formatKg(item.kilograms)}'),
                subtitle: Text('${formatCurrency(item.ratePerKg)}/kg'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCurrency(item.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => salesProvider.removeCartItem(index),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(context, 'total_label'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(formatCurrency(cartTotal),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _givenController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, 'amount_given_label'),
              prefixIcon: const Icon(Icons.payments_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(context, 'balance_label_bold'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                formatCurrency(balance),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SavingButton(
            label: tr(context, 'save_sale_button'),
            onPressed: () => _save(salesProvider),
          ),
        ],
      ),
    );
  }
}
