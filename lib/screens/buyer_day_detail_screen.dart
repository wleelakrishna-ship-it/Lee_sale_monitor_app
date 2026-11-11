import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/payment.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';
import '../utils/formatters.dart';

class BuyerDayDetailScreen extends StatefulWidget {
  final String buyerName;

  const BuyerDayDetailScreen({super.key, required this.buyerName});

  @override
  State<BuyerDayDetailScreen> createState() => _BuyerDayDetailScreenState();
}

class _BuyerDayDetailScreenState extends State<BuyerDayDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadBuyerDayDetail(widget.buyerName);
    });
  }

  Future<void> _editSale(Sale sale) async {
    final rateController = TextEditingController(text: sale.ratePerKg.toString());
    final kgController = TextEditingController(text: sale.kilograms.toString());
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
            final rate = double.parse(rateController.text);
            final kg = double.parse(kgController.text);
            try {
              await salesProvider.updateSaleItem(
                Sale(
                  id: sale.id,
                  date: sale.date,
                  buyerName: sale.buyerName,
                  category: sale.category,
                  ratePerKg: rate,
                  kilograms: kg,
                  amount: rate * kg,
                  createdAt: sale.createdAt,
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
            title: Text(tr(context, 'edit_dynamic_title', {'category': sale.category})),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: rateController,
                    autofocus: true,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'rate_per_kg_field')),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return tr(context, 'enter_valid_rate');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: kgController,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(context, 'kilograms_field')),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return tr(context, 'enter_valid_weight');
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

  Future<void> _deleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'delete_sale_item_title')),
        content: Text(tr(context, 'delete_sale_item_body', {
          'category': sale.category,
          'kg': formatKg(sale.kilograms),
          'buyer': sale.buyerName,
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
        await context.read<SalesProvider>().deleteSaleItem(sale.id!, sale.buyerName);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, 'local_save_failed_message'))));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'sale_item_deleted'))));
    }
  }

  Future<void> _editPayment(Payment payment) async {
    final controller = TextEditingController(text: payment.amountGiven.toString());
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
              await salesProvider.updatePaymentItem(
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
        await context.read<SalesProvider>().deletePaymentItem(payment.id!, payment.buyerName);
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

  String _formatTime(String isoCreatedAt) {
    final parsed = DateTime.tryParse(isoCreatedAt);
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final sales = provider.buyerSales;
    final payments = provider.buyerPayments;

    return Scaffold(
      appBar: AppBar(title: Text(widget.buyerName)),
      body: provider.buyerDetailLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(tr(context, 'sale_items_section'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (sales.isEmpty)
                  Text(tr(context, 'no_sale_items_today'))
                else
                  ...sales.map(
                    (sale) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(sale.category),
                        subtitle: Text(
                          '${formatCurrency(sale.ratePerKg)}/kg • ${formatKg(sale.kilograms)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatCurrency(sale.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editSale(sale),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteSale(sale),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(tr(context, 'payments_section'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (payments.isEmpty)
                  Text(tr(context, 'no_payments_today'))
                else
                  ...payments.map(
                    (payment) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(formatCurrency(payment.amountGiven)),
                        subtitle: Text(_formatTime(payment.createdAt)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editPayment(payment),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deletePayment(payment),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
