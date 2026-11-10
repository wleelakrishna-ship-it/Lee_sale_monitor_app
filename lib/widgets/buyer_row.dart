import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/buyer_summary.dart';
import '../utils/formatters.dart';

class BuyerRow extends StatelessWidget {
  final BuyerSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const BuyerRow({super.key, required this.summary, this.onTap, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final balance = summary.balance;
    final balanceColor = balance > 0 ? Colors.red.shade700 : Colors.green.shade700;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(summary.buyerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatKg(summary.totalKilograms)} • ${tr(context, 'total_label')} ${formatCurrency(summary.total)} '
          '• ${tr(context, 'given_word')} ${formatCurrency(summary.given)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(balance),
                  style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold),
                ),
                Text(tr(context, 'balance_caption'), style: TextStyle(color: balanceColor, fontSize: 11)),
              ],
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: tr(context, 'edit_entries_tooltip'),
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
