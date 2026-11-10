import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/buyer_overview.dart';
import '../providers/buyers_provider.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';
import 'buyer_detail_screen.dart';

class BuyersScreen extends StatefulWidget {
  const BuyersScreen({super.key});

  @override
  State<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends State<BuyersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuyersProvider>().loadAllBuyers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BuyersProvider>();
    final buyers = provider.filteredBuyers;
    final totalOutstanding = provider.allBuyers
        .fold(0.0, (sum, b) => sum + (b.balance > 0 ? b.balance : 0));

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'buyers_title'))),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<BuyersProvider>().loadAllBuyers(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SummaryCard(
                    title: tr(context, 'total_outstanding_across_buyers'),
                    value: formatCurrency(totalOutstanding),
                    icon: Icons.account_balance_wallet_outlined,
                    color: totalOutstanding > 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => context.read<BuyersProvider>().setSearchQuery(value),
                    decoration: InputDecoration(
                      labelText: tr(context, 'search_buyer_label'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (buyers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(tr(context, 'no_buyers_found'), textAlign: TextAlign.center),
                    )
                  else
                    ...buyers.map((buyer) => _BuyerOverallRow(
                          buyer: buyer,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BuyerDetailScreen(buyerName: buyer.buyerName),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _BuyerOverallRow extends StatelessWidget {
  final BuyerOverallSummary buyer;
  final VoidCallback onTap;

  const _BuyerOverallRow({required this.buyer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final balance = buyer.balance;
    final balanceColor = balance > 0 ? Colors.red.shade700 : Colors.green.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(buyer.buyerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          tr(context, 'total_purchased_prefix', {
            'amount': formatCurrency(buyer.totalAmount),
            'kg': formatKg(buyer.totalKilograms),
          }),
        ),
        trailing: Column(
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
      ),
    );
  }
}
