import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/sales_provider.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';
import 'buyers_screen.dart';
import 'investors_expenses_screen.dart';
import 'profit_shares_screen.dart';
import 'rates_setup_screen.dart';
import 'reports_screen.dart';
import 'sale_entry_screen.dart';
import 'today_overview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadTodayOverview();
      context.read<LanguageProvider>().loadSavedLanguage();
    });
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr(context, 'choose_language')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              context.read<LanguageProvider>().setLanguage(AppLanguage.english);
              Navigator.pop(dialogContext);
            },
            child: Text(tr(context, 'language_english')),
          ),
          SimpleDialogOption(
            onPressed: () {
              context.read<LanguageProvider>().setLanguage(AppLanguage.tamil);
              Navigator.pop(dialogContext);
            },
            child: Text(tr(context, 'language_tamil')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'sign_out_confirm_title')),
        content: Text(tr(context, 'sign_out_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, 'sign_out_tooltip')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final totals = sales.dayTotals;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: tr(context, 'change_language'),
            onPressed: () => _showLanguageDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: tr(context, 'sign_out_tooltip'),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<SalesProvider>().loadTodayOverview(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              formatDisplayDate(todayDateOnly()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: tr(context, 'today_amount'),
                    value: formatCurrency(totals.totalAmount),
                    icon: Icons.currency_rupee,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title: tr(context, 'kilograms_sold'),
                    value: formatKg(totals.totalKg),
                    icon: Icons.scale,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title: tr(context, 'buyers_today'),
                    value: '${totals.buyerCount}',
                    icon: Icons.groups,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _NavCard(
              icon: Icons.sell,
              title: tr(context, 'nav_new_sale_title'),
              subtitle: tr(context, 'nav_new_sale_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SaleEntryScreen())),
            ),
            _NavCard(
              icon: Icons.price_change,
              title: tr(context, 'nav_rates_title'),
              subtitle: tr(context, 'nav_rates_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RatesSetupScreen())),
            ),
            _NavCard(
              icon: Icons.fact_check,
              title: tr(context, 'nav_overview_title'),
              subtitle: tr(context, 'nav_overview_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const TodayOverviewScreen())),
            ),
            _NavCard(
              icon: Icons.insert_chart,
              title: tr(context, 'nav_reports_title'),
              subtitle: tr(context, 'nav_reports_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
            _NavCard(
              icon: Icons.people_alt,
              title: tr(context, 'nav_buyers_title'),
              subtitle: tr(context, 'nav_buyers_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const BuyersScreen())),
            ),
            _NavCard(
              icon: Icons.account_balance,
              title: tr(context, 'nav_investors_title'),
              subtitle: tr(context, 'nav_investors_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const InvestorsExpensesScreen())),
            ),
            _NavCard(
              icon: Icons.volunteer_activism,
              title: tr(context, 'nav_profit_shares_title'),
              subtitle: tr(context, 'nav_profit_shares_subtitle'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfitSharesScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
